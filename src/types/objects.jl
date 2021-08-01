import Dates: DateTime, unix2datetime, datetime2unix

struct JsObject <: JsObjectType
    ref::NodeObject
end

struct JsIterator <: JsObjectType
    ref::NodeObject
end

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
    argc = isnothing(args) ? 0 : length(args)
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

@global_js_const _JS_DICT_PROXY = raw"""(() => {
    const preserved_keys = [
        "__get__", "__set__", "__has__", "__keys__",
        "__jl_type", "__jl_ptr"
    ]
    return (dict) => new Proxy(dict, {
        get: function (target, prop) {
            if (prop === "__jl_type" || prop === "__jl_ptr") {
                return Reflect.get(target, prop)
            }
            return target.__get__(prop)
        },
        set: (target, prop, value) => {
            target.__set__(prop, value)
        },
        has: (target, prop) => target.__has__(prop),
        ownKeys: (target) => {
            const keys = [...preserved_keys]
            for (const key of target.__keys__()) {
                keys.push(key.toString())
            }
            return keys
        },
        getOwnPropertyDescriptor: function (target, prop) {
            if (preserved_keys.includes(prop)) {
                return Object.getOwnPropertyDescriptor(target, prop)
            }
            return {
                get: () => this.get(target, prop),
                set: () => this.set(target, prop),
                enumerable: true,
                configurable: true
            }
        }
    })
})()"""
function create_object_dict(x::AbstractDict{String})
    ref = reference(x)
    t = @napi_call create_object_dict(
        pointer(ref)::Ptr{Cvoid}
    )::NapiValue
    add_finalizer!(t, dereference, x)
    _JS_DICT_PROXY(t; raw=true)
end
function create_object_dict(x::AbstractDict)
    m = run_script("new Map()", raw=true)
    for (k, v) in x
        m.set(k, v)
    end
    m
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

add_jltype(::Type{T}) where T = NapiPropertyDescriptor(
    utf8name=pointer(_JLTYPE_PROPERTY),
    value=NodeExternal(T),
    attributes=NapiTypes.napi_default
)

napi_value(js_object::JsObjectType) = convert(NapiValue, getfield(js_object, :ref))
napi_value(v::DateTime) = @napi_call napi_create_date((datetime2unix(v) * 1000)::Cdouble)::NapiValue
const _JLTYPE_PROPERTY = "__jl_type"
const _JLPTR_PROPERTY = "__jl_ptr"
function napi_value(v::T; vtype = nothing) where T
    mut = ismutable(v)
    nv = if vtype ≡ :strdict || vtype ≡ :dict
        create_object_dict(v)
    elseif vtype ≡ :tuple
        create_object_tuple(v)
    elseif mut
        create_object_mutable(v)
    else
        create_object_immutable(v)
    end
    ps = [add_jltype(T)]
    if mut
        push!(ps, NapiPropertyDescriptor(
            utf8name=pointer(_JLPTR_PROPERTY),
            value=NodeExternal(v),
            attributes=NapiTypes.napi_default
        ))
    end
    define_properties!(nv, ps)
    nv
end
napi_value(d::AbstractDict{String}) = napi_value(d, vtype = :strdict)
napi_value(d::AbstractDict) = napi_value(d, vtype = :dict)
napi_value(t::Tuple) = napi_value(t, vtype = :tuple)

value(::Type{JsObject}, v::NapiValue) = JsObject(NodeObject(v))
value(::Type{DateTime}, v::NapiValue) = @with_scope begin
    val = @napi_call napi_get_date_value(v::NapiValue)::Cdouble
    unix2datetime(val / 1000)
end

_get_cached(v::NapiValue) = @with_scope begin
    jltype_external = @napi_call napi_get_named_property(v::NapiValue, _JLTYPE_PROPERTY::Cstring)::NapiValue
    get_type(jltype_external) == NapiTypes.napi_undefined && return nothing
    T = value(NodeExternal, jltype_external)::DataType
    isnothing(T) && return nothing
    if T <: AbstractDict && !(T <: AbstractDict{String})
        return value(T, v)
    elseif T.mutable
        jlobject_external = @napi_call napi_get_named_property(v::NapiValue, _JLPTR_PROPERTY::Cstring)::NapiValue
        get_type(jlobject_external) == NapiTypes.napi_undefined && return nothing
        value(NodeExternal(jlobject_external))
    elseif T <: Tuple
        T(v[i-1] for i in 1:length(T.types))
    elseif T <: NamedTuple
        T(v[string(key)] for key in fieldnames(T))
    else
        T((v[string(key)] for key in fieldnames(T))...)
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

value(::Type{T}, v::NapiValue) where T <: AbstractDict = let dict = value(Dict, v)
    try return T(dict) catch end
    dict
end
value(::Type{Dict}, v::NapiValue) = @with_scope is_map(v) ? make_dict(v) : Dict(key => v[key] for key in keys(v))
value(::Type{T}, v::NapiValue) where T <: AbstractSet = let set = value(Set, v)
    try return T(set) catch end
    set
end
value(::Type{Set}, v::NapiValue) = @with_scope is_set(v) ? make_set(v) : Set(keys(v))
Base.Dict(v::ValueTypes) = value(Dict, v)
Base.Set(v::ValueTypes) = value(Set, v)

@global_js_const _MAKE_DICT = """(v) => {
    assert(v instanceof Map || v instanceof WeakMap)
    const ks = []
    const vs = []
    for (const x of v) {
        ks.push(x[0])
        vs.push(x[1])
    }
    return [ks, vs]
}"""
function make_dict(v::NapiValue)
    ks, vs = _MAKE_DICT(v)
    Dict(zip(ks, vs))
end

@global_js_const _MAKE_SET = """(v) => {
    assert(v instanceof Set || v instanceof WeakSet)
    const vs = []
    for (const x of v) {
        vs.push(x)
    }
    return vs
}"""
function make_set(v::NapiValue)
    vs = _MAKE_SET(v)
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

macro new(expr)
    constructor, args = if expr isa Symbol
        expr, NapiValue[]
    else
        @assert expr isa Expr && expr.head == :call
        expr.args[1], Expr(:tuple, expr.args[2:end]...)
    end
    esc(:(create_object($constructor, $args)))
end
