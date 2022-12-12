import Dates: DateTime, unix2datetime, datetime2unix
import JSON

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
    result=RESULT_VALUE
) = with_result(result) do
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

@global_node_const _JS_OBJECT = "Object"
@global_node_const _JS_OBJECT_KEYS_LENGTH = "(o) => Object.keys(o).length"
@global_node_const _JS_OBJECT_PROXY = raw"""(() => {
    const preserved_keys = [
        "__get__", "__set__", "__has__", "__keys__",
        "__jl_type", "__jl_ptr"
    ]
    return (object) => new Proxy(object, {
        get: function (target, prop) {
            if (prop === "__jl_type" || prop === "__jl_ptr") {
                return Reflect.get(target, prop)
            } else if (prop === "toJSON" && !this.has(target, prop)) {
                return () => {
                    const x = new Object()
                    for (const key of target.__keys__()) {
                        x[key] = this.get(target, key)
                    }
                    return JSON.stringify(x)
                }
            }
            return target.__get__(prop)
        },
        set: (target, prop, value) => {
            target.__set__(prop, value)
        },
        has: (target, prop) => target.__has__(prop),
        ownKeys: (target) => {
            const keys = Reflect.ownKeys(target)
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
@global_node_const _JS_SET_ADD = "(m, v) => m.add(v)"

create_object_dict(x::AbstractDict) = create_object_mutable(x)
function create_object_set(x::AbstractSet)
    m = node_eval("new Set()", RESULT_RAW)
    for v in x
        _JS_SET_ADD(m, v; result=RESULT_RAW)
    end
    m
end
create_object_tuple(x) = _napi_value(collect(x))
function create_object_mutable(x)
    ref = pointer(reference(x))
    v = @napi_call libjlnode.create_object_mutable(
        ref::Ptr{Cvoid}
    )::NapiValue
    add_finalizer!(v, dereference, ref)
    _JS_OBJECT_PROXY(v; result=RESULT_RAW)
end
function create_object_immutable(x::T) where {T}
    nv = create_object(result=RESULT_RAW)
    for k in fieldnames(T)
        nv[string(k)] = getfield(x, k)
    end
    nv
end

add_jltype(::Type{T}) where {T} = NapiPropertyDescriptor(
    utf8name=pointer(_JLTYPE_PROPERTY),
    value=NodeExternal(T),
    attributes=NapiTypes.napi_default
)

napi_value(js_object::JsObjectType) = convert(NapiValue, getfield(js_object, :ref))
napi_value(v::DateTime) = @napi_call napi_create_date((datetime2unix(v) * 1000)::Cdouble)::NapiValue
const _JLTYPE_PROPERTY = "__jl_type"
const _JLPTR_PROPERTY = "__jl_ptr"
function napi_value(v::T; vtype=nothing) where {T}
    mut = ismutable(v)
    nv = if vtype ≡ :dict
        create_object_dict(v)
    elseif vtype ≡ :set
        create_object_set(v)
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
napi_value(d::AbstractDict) = napi_value(d, vtype=:dict)
napi_value(s::AbstractSet) = napi_value(s, vtype=:set)
napi_value(t::Tuple) = napi_value(t, vtype=:tuple)

value(::Type{JsObject}, v::NapiValue) = JsObject(NodeObject(v))
value(::Type{DateTime}, v::NapiValue) = @with_scope begin
    val = @napi_call napi_get_date_value(v::NapiValue)::Cdouble
    unix2datetime(val / 1000)
end

_get_cached(v::NapiValue) = @with_scope begin
    jltype_external = @napi_call napi_get_named_property(v::NapiValue, _JLTYPE_PROPERTY::Cstring)::NapiValue
    get_type(jltype_external) ≡ NapiTypes.napi_undefined && return nothing
    T = value(NodeExternal, jltype_external)::DataType
    isnothing(T) && return nothing
    if T <: AbstractSet
        return value(T, v)
    elseif ismutabletype(T)
        jlobject_external = @napi_call napi_get_named_property(v::NapiValue, _JLPTR_PROPERTY::Cstring)::NapiValue
        get_type(jlobject_external) == NapiTypes.napi_undefined && return nothing
        value(NodeExternal(jlobject_external))
    elseif T <: Tuple
        len = length(T.types)
        length(v) == len || return nothing
        T(v[i-1] for i in 1:len)
    elseif T <: NamedTuple
        len = _JS_OBJECT_KEYS_LENGTH(v)
        length(T.types) == len || return nothing
        T(v[string(key)] for key in fieldnames(T))
    else
        len = _JS_OBJECT_KEYS_LENGTH(v)
        length(T.types) == len || return nothing
        T((v[string(key)] for key in fieldnames(T))...)
    end
end

function object_value(v::NapiValue)
    try
        cached = _get_cached(v)
        isnothing(cached) || return cached
    catch _
    end
    if is_date(v)
        value(DateTime, v)
    elseif is_array(v)
        value(Array, v; array_type=:array)
    elseif is_typedarray(v)
        value(Array, v; array_type=:typedarray)
    elseif is_arraybuffer(v)
        value(Array, v; array_type=:arraybuffer)
    elseif is_dataview(v)
        value(Array, v; array_type=:dataview)
    elseif is_buffer(v)
        value(Array, v; array_type=:buffer)
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

function value(::Type{T}, v::NapiValue) where {T<:AbstractDict}
    dict = value(Dict, v)
    try
        return T(dict)
    catch
    end
    dict
end
_dict_value(nv::NapiValue, depth=1) = Dict(
    key => let v = nv[key]
        depth != 0 && v isa JsObject ? _dict_value(napi_value(v), depth - 1) : v
    end for key in keys(nv)
)
value(::Type{Dict}, nv::NapiValue; depth=1) = @with_scope is_map(nv) ? make_dict(nv) : _dict_value(nv, depth)
value(::Type{T}, v::NapiValue) where {T<:AbstractSet} =
    let set = value(Set, v)
        try
            return T(set)
        catch
        end
        set
    end
value(::Type{Set}, v::NapiValue) = @with_scope is_set(v) ? make_set(v) : Set(keys(v))
Base.Dict(v::ValueTypes; depth=2) = @with_scope _dict_value(napi_value(v), depth)
Base.Set(v::ValueTypes) = value(Set, v)

@global_node_const _MAKE_DICT = """(v) => {
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

@global_node_const _MAKE_SET = """(v) => {
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

Base.NamedTuple(v::ValueTypes) = value(NamedTuple, v)
value(::Type{T}, v::NapiValue) where {T<:NamedTuple} = @with_scope T(
    v[string(k)] for k in fieldnames(T)
)
value(::Type{NamedTuple}, v::NapiValue) = @with_scope NamedTuple(
    k => v[string(k)] for k in propertynames(v)
)

function add_finalizer!(nv::NapiValue, f::Function, data=nothing)
    f_ptr = pointer(reference(f))
    data_ptr = isnothing(data) ? C_NULL : pointer(reference(data))
    @napi_call libjlnode.add_finalizer(
        nv::NapiValue, f_ptr::Ptr{Cvoid}, data_ptr::Ptr{Cvoid}
    )
    nv
end

function object_finalizer(f_ptr, data_ptr)
    initialized() || return
    try
        f = dereference(f_ptr)[]
        data = dereference(data_ptr)
        f(value(data))
    catch
    end
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

JSON.lower(x::ValueTypes) = Dict(x, depth=0)
