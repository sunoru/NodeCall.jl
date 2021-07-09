import Dates: DateTime, unix2datetime, datetime2unix

struct JsObject <: JsObjectType
    ref::NodeObject
end

function create_object(properties::Union{
    Nothing, AbstractArray{NapiPropertyDescriptor}, AbstractArray{NapiPropertyDescriptor}
} = nothing)
    nv = @napi_call napi_create_object()::NapiValue
    if !isnothing(properties)
        @napi_call napi_define_properties(
            nv::NapiValue,
            length(properties)::Csize_t,
            properties::Ptr{NapiPropertyDescriptor}
        )
    end
    nv
end

function dict_getter(_env, _info)
    info = get_callback_info(_info, 1)
    x = get(JuliaObjectCache, info.data, nothing)
    isnothing(x) && return get_undefined()
    x[1][info.argv[1]]
end
function dict_setter(_env, _info)
    info = get_callback_info(_info, 2)
    x = get(JuliaObjectCache, info.data, nothing)
    isnothing(x) && return get_undefined()
    x[1][info.argv[1]] = value(info.argv[2])
    x[1][info.argv[1]]
end
function mutable_getter(_env, _info)
    info = get_callback_info(_info, 1)
    x = get(JuliaObjectCache, info.data, nothing)
    isnothing(x) && return get_undefined()
    x[1][info.argv[1]]
end
function mutable_setter(_env, _info)
    info = get_callback_info(_info, 2)
    x = get(JuliaObjectCache, info.data, nothing)
    isnothing(x) && return get_undefined()
    x[1][info.argv[1]] = value(info.argv[2])
    x[1][info.argv[1]]
end
get_dict_descriptors(x) = [begin
    NapiPropertyDescriptor(
        name = string(k),
        getter = create_callback(dict_getter),
        setter = create_callback(dict_setter),
        data = pointer_from_objref(x),
        attributes = NapiTypes.napi_writable
    )
end for k in keys(x)]
get_mutable_descriptors(x) = [begin
    NapiPropertyDescriptor(
        name = string(k),
        getter = create_callback(mutable_getter),
        setter = create_callback(mutable_setter),
        data = pointer_from_objref(x),
        attributes = NapiTypes.napi_writable
    )
end for k in propertynames(x)]
get_immutable_descriptors(x) = [NapiPropertyDescriptor(
    name = string(k),
    value = NapiValue(getfield(x, k))
) for k in fieldnames(x)]

const JuliaTypeCache = Dict{Ptr{Type}, Type}()
const JuliaObjectCache = Dict{NapiPointer, Tuple{Any, NodeObject, Vector{NapiPropertyDescriptor}}}()
function add_jltype!(properties, ::Type{T}) where T
    p = Ptr{Type}(pointer_from_objref(T))
    if !haskey(JuliaTypeCache, p)
         JuliaTypeCache[p] = T
    end
    push!(properties, NapiPropertyDescriptor(
        name = _JLTYPE_PROPERTY,
        attributes = NapiTypes.napi_default,
        value = NodeExternal(p)
    ))
end

const _JLTYPE_PROPERTY = "__jl_type"
const _JLPTR_PROPERTY = "__jl_ptr"
napi_value(js_object::JsObjectType) = convert(NapiValue, getfield(js_object, :ref))
napi_value(v::DateTime) = @napi_call napi_create_date(datetime2unix(v)::Cdouble)::NapiValue
function napi_value(v::T; isdict=false) where T
    mut = ismutable(v)
    ptr = nothing
    if mut
        ptr = NapiPointer(pointer_from_objref(v))
        haskey(JuliaObjectCache, ptr) && return NapiValue(JuliaObjectCache[ptr][2])
    end
    properties = if isdict
        get_dict_descriptors(v)
    elseif mut
        get_mutable_descriptors(v)
    else
        get_immutable_descriptors(v)
    end
    add_jltype!(properties, T)
    if mut
        push!(properties, NapiPropertyDescriptor(
            name = _JLPTR_PROPERTY,
            attributes = NapiTypes.napi_default,
            value = NodeExternal(ptr, () -> delete!(JuliaObjectCache, ptr))
        ))
    end
    nv = create_object(properties)
    if mut
        JuliaObjectCache[ptr] = (v, node_value(nv), properties)
    end
    nv
end
napi_value(d::AbstractDict) = napi_value(d, isdict=true)

value(::Type{JsObject}, v::NapiValue) = JsObject(NodeObject(v))
value(::Type{DateTime}, v::NapiValue) = open_scope() do _
    val = @napi_call napi_get_date_value(v::NapiValue)::Cdouble
    unix2datetime(val / 1000)
end

_get_cached(v::NapiValue) = open_scope() do _
    jltype = @napi_call napi_get_property(v::NapiValue, _JLTYPE_PROPERTY::NapiValue)::NapiValue
    get_type(jltype) == NapiTypes.napi_undefined && return nothing
    jltype_ptr = Ptr{Type}(getfield(value(NodeExternal{T}, jltype), :ptr))
    T = get(JuliaTypeCache, jltype_ptr, nothing)
    isnothing(T) && return nothing
    if getfield(T, :mutable)
        jlobject = @napi_call napi_get_property(v::NapiValue, _JLPTR_PROPERTY::NapiValue)::NapiValue
        get_type(jlobject) == NapiTypes.napi_undefined && return nothing
        jlobject_ptr = Ptr{T}(getfield(value(NodeExternal{T}, jltype), :ptr))
        if haskey(JuliaObjectCache, jlobject_ptr)
            unsafe_load(jlobject_ptr)
        else
            nothing
        end
    else
        T(v[key] for key in fieldnames(T))
    end
end

function object_value(v::NapiValue)
    if is_date(v)
        value(DateTime, v)
    elseif is_array(v)
        value(Array, v; array_type = :array)
    elseif is_typedarray(v)
        value(Array, v; array_type = :typedarray)
    elseif is_arraybuffer(v)
        value(Array, v; array_type = :arraybuffer)
    elseif is_dataview(v)
        value(Array, v; array_type = :dataview)
    elseif is_buffer(v)
        value(Array, v; array_type = :buffer)
    elseif is_map(v)
        value(Dict, v)
    elseif is_set(v)
        value(Set, v)
    elseif is_promise(v)
        value(JsPromise, v)
    else
        cached = _get_cached(v)
        isnothing(cached) || return cached
        value(JsObject, v)
    end
end

value(::Type{T}, v::NapiValue) where T <: AbstractDict = T(value(Dict, v))
value(::Type{Dict}, v::NapiValue) = @with_scope is_map(v) ? make_dict(v) : Dict(key => v[key] for key in keys(v))
value(::Type{T}, v::NapiValue) where T <: AbstractSet = T(value(Set, v))
value(::Type{Set}, v::NapiValue) = @with_scope is_set(v) ? make_set(v) : Set(keys(v))
Base.Dict(v::ValueTypes) = value(Dict, v)
Base.Set(v::ValueTypes) = value(Set, v)

function make_dict(v::NapiValue)
    ks, vs = node"""(v) => {
    assert(v instanceof Map || v instanceof WeakMap)
    const ks = []
    const vs = []
    for (const x of v) {
        ks.push(x[0])
        vs.push(x[1])
    }
    return [ks, vs]
    }"""(v)
    Dict(zip(ks, vs))
end

function make_set(v::NapiValue)
    vs = node"""(v) => {
    assert(v instanceof Set || v instanceof WeakSet)
    const vs = []
    for (const x of v) {
        vs.push(x)
    }
    return vs
    }"""(v)
    Set(vs)
end
