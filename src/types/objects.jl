import Dates: DateTime, unix2datetime, datetime2unix

struct JsObject <: JsObjectType
    ref::NodeObject
end

function create_object(properties::Union{Nothing, AbstractArray{NapiPropertyDescriptor}} = nothing)
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
get_descriptors(x) = [
    NapiPropertyDescriptor(
        utf8name=string(k),
        value=NapiValue(v)
    ) for (k, v) in x
]
get_property_descriptors(x) = get_descriptors(
    (k, getproperty(x, k)) for k in propertynames(x)
)
get_field_descriptors(x::T) where T = get_descriptors(
    (k, getfield(x, k)) for k in fieldnames(T)
)

const JuliaTypeCache = Dict{Ptr{Type}, Type}()
const JuliaObjectCache = Dict{NapiPointer, Tuple{Any, NodeObject}}()
add_jltype(::Type{T}) where T = let p = Ptr{Type}(pointer_from_objref(T))
    if !haskey(JuliaTypeCache, p)
         JuliaTypeCache[p] = T
    end
    NapiValue(UInt64(p))
end

const _JLTYPE_PROPERTY = "__jl_type"
const _JLPTR_PROPERTY = "__jl_ptr"
napi_value(js_object::JsObjectType) = convert(NapiValue, getfield(js_object, :ref))
napi_value(v::DateTime) = @napi_call napi_create_date(datetime2unix(v)::Cdouble)::NapiValue
function napi_value(v::T; isdict=false) where T
    mut = mutable(v)
    if mut
        ptr = NapiPointer(pointer_from_objref(v))
        haskey(JuliaObjectCache, ptr) && return NapiValue(JuliaObjectCache[ptr][2])
    end
    properties = if isdict
        get_descriptors(v)
    elseif mut
        get_properties_descriptors(v)
    else
        get_field_descriptors(v)
    end
    push!(properties, NapiPropertyDescriptor(
        utf8name = _JLTYPE_PROPERTY,
        attributes = NapiTypes.napi_default,
        value = add_jltype(T)
    ))
    if mut
        push!(properties, NapiPropertyDescriptor(
            utf8name = _JLPTR_PROPERTY,
            attributes = NapiTypes.napi_default,
            value = NapiValue(UInt64(ptr))
        ))
    end
    nv = create_object(properties)
    if mut
        JuliaObjectCache[ptr] = (v, NodeObject(nv))
    end
    nv
end
napi_value(d::AbstractDict) = napi_value(d, isdict=true)

value(::Type{JsObject}, v::NapiValue) = JsObject(NodeObject(v))
value(::Type{DateTime}, v::NapiValue) = open_scope() do _
    val = @napi_call napi_get_date_value(v::NapiValue)::Cdouble
    unix2datetime(val / 1000)
end

function _get_cached(v::NapiValue)
    jltype = @napi_call napi_get_named_property(v::NapiValue, _JLTYPE_PROPERTY::Cstring)::NapiValue
    get_type(jltype) == NapiTypes.napi_undefined && return nothing
    jltype_ptr = Ptr{Type}(value(UInt64, jltype))
    T = get(JuliaTypeCache, jltype_ptr, nothing)
    isnothing(T) && return nothing
    if T.mutable
        jlobject = @napi_call napi_get_named_property(v::NapiValue, _JLPTR_PROPERTY::Cstring)::NapiValue
        get_type(jlobject) == NapiTypes.napi_undefined && return nothing
        jlobject_ptr = NapiPointer(value(UInt64, jlobject))
        if haskey(JuliaObjectCache, jlobject_ptr)
            JuliaObjectCache[ptr][1]::T
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
