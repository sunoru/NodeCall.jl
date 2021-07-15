import Dates: DateTime, unix2datetime, datetime2unix

struct JsObject <: JsObjectType
    ref::NodeObject
end

struct JsIterator <: JsObjectType
    ref::NodeObject
end

# FIXME:
# `define_properties!` leads to ReadOnlyMemoryError()
function define_properties!(nv::NapiValue, properties::AbstractArray{NapiPropertyDescriptor})
    @napi_call napi_define_properties(
        nv::NapiValue,
        length(properties)::Csize_t,
        properties::Ptr{NapiPropertyDescriptor}
    )
    nv
end
create_object(
    constructor=nothing, args=nothing;
    raw=false, convert_result=true
) = with_result(raw, convert_result) do
    argv = isnothing(args) ? C_NULL : NapiValue.(collect(args))
    argc = length(argv)
    if isnothing(constructor)
        @napi_call napi_create_object()::NapiValue
    else
        @napi_call napi_new_instance(
            constructor::NapiValue,
            argc::Csize_t,
            argv::Ptr{NapiValue}
        )::NapiValue
    end
end

create_object(
    properties::AbstractArray{NapiPropertyDescriptor};
    raw=false, convert_result=true
) = with_result(raw, convert_result) do
    nv = @napi_call napi_create_object()::NapiValue
    define_properties!(nv, properties)
    nv
end

function create_object_dict(x)
    t = @napi_call create_object_dict(
        pointer_from_objref(x)::Ptr{Cvoid}
    )::NapiValue
    f = run_node(raw"""(dict) => new Proxy(dict, {
        get: (target, prop) => {
            if (prop === '__jl_type' || prop === '__jl_ptr') {
                return Reflect.get(this, prop)
            }
            return target.__get__(prop)
        },
        set: (target, prop, value) => {
            if (prop === '__jl_type' || prop === '__jl_ptr') {
                Object.defineProperty(this, prop, {value})
                return
            }
            target.__set__(prop, value)
        },
        has: (target, prop) => target.__has__(prop),
        ownKeys: (target) => target.__keys__()
            .concat(["__get__", "__set__", "__has__", "__keys__"])
    })"""; raw=true)
    f(t; raw=true)
end
create_object_tuple(x) = _napi_value(collect(x))
create_object_mutable(x) = @napi_call create_object_mutable(
    pointer_from_objref(x)::Ptr{Cvoid}
)::NapiValue
function create_object_immutable(x::T) where T
    nv = create_object(raw=true)
    for k in fieldnames(T)
        nv[string(k)] = getfield(x, k)
    end
    nv
end

# function add_jltype(::Type{T}) where T
function add_jltype!(nv, ::Type{T}) where T
    nv[_JLTYPE_PROPERTY] = NodeExternal(T)
    nv
end

napi_value(js_object::JsObjectType) = convert(NapiValue, getfield(js_object, :ref))
napi_value(v::DateTime) = @napi_call napi_create_date((datetime2unix(v) * 1000)::Cdouble)::NapiValue
const _JLTYPE_PROPERTY = "__jl_type"
const _JLPTR_PROPERTY = "__jl_ptr"
function napi_value(v::T; vtype = nothing) where T
    mut = ismutable(v)
    ptr = nothing
    if mut
        ptr = pointer_from_objref(v)
        nv = get_reference(ptr)
        isnothing(nv) || return NapiValue(nv[])
    end
    nv = if vtype ≡ :dict
        create_object_dict(v)
    elseif vtype ≡ :tuple
        create_object_tuple(v)
    elseif mut
        create_object_mutable(v)
    else
        create_object_immutable(v)
    end
    add_jltype!(nv, T)
    if mut
        nv[_JLPTR_PROPERTY] = NodeExternal(v)
    end
    nv
end
napi_value(d::AbstractDict) = napi_value(d, vtype = :dict)
napi_value(t::Tuple) = napi_value(t, vtype = :tuple)

value(::Type{JsObject}, v::NapiValue) = JsObject(NodeObject(v))
value(::Type{DateTime}, v::NapiValue) = open_scope() do _
    val = @napi_call napi_get_date_value(v::NapiValue)::Cdouble
    unix2datetime(val / 1000)
end

_get_cached(v::NapiValue) = open_scope() do _
    jltype_external = @napi_call napi_get_named_property(v::NapiValue, _JLTYPE_PROPERTY::Cstring)::NapiValue
    get_type(jltype_external) == NapiTypes.napi_undefined && return nothing
    T = value(NodeExternal, jltype_external)::DataType
    isnothing(T) && return nothing
    if T.mutable
        jlobject_external = @napi_call napi_get_named_property(v::NapiValue, _JLPTR_PROPERTY::Cstring)::NapiValue
        get_type(jlobject_external) == NapiTypes.napi_undefined && return nothing
        value(NodeExternal(jlobject_external))
    elseif T <: Tuple
        T((value(t, v[i-1]) for (i, t) in enumerate(T.types))...)
    else
        T((v[string(key)] for key in fieldnames(T) if string(key) != _JLTYPE_PROPERTY)...)
    end
end

function object_value(v::NapiValue)
    cached = _get_cached(v)
    isnothing(cached) || return cached
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
    elseif is_iterator(v)
        value(JsIterator, v)
    elseif is_promise(v)
        value(JsPromise, v)
    else
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

function add_finalizer!(nv::NapiValue, f::Function, data=nothing)
    f_ptr = pointer(reference(f))
    data_ptr = isnothing(data) ? C_NULL : pointer(reference(data))
    @napi_call add_finalizer(
        nv::NapiValue, f_ptr::Ptr{Cvoid}, data_ptr::Ptr{Cvoid}
    )
    nv
end

function object_finalizer(f_ptr, data_ptr)
    f = value(dereference(f_ptr))
    data = dereference(data_ptr)
    f(value(data))
end
