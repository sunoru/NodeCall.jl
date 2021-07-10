import Dates: DateTime, unix2datetime, datetime2unix

struct JsObject <: JsObjectType
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
function create_object(constructor=nothing, args=nothing; raw=false)
    scope = raw ? nothing : open_scope()
    argv = isnothing(args) ? C_NULL : NapiValue.(collect(args))
    argc = length(argv)
    nv = if isnothing(constructor)
        @napi_call napi_create_object()::NapiValue
    else
        @napi_call napi_new_instance(
            constructor::NapiValue,
            argc::Csize_t,
            argv::Ptr{NapiValue}
        )::NapiValue
    end
    ret = raw ? nv : value(nv)
    close_scope(scope)
    ret
end

function create_object(properties::AbstractArray{NapiPropertyDescriptor}; raw=false)
    scope = raw ? nothing : open_scope()
    nv = @napi_call napi_create_object()::NapiValue
    define_properties!(nv, properties)
    ret = raw ? nv : value(nv)
    close_scope(scope)
    ret
end

function create_object_dict(x)
    t = @napi_call create_object_dict(
        pointer_from_objref(x)::Ptr{Cvoid}
    )::NapiValue
    f = run(raw"""(dict) => new Proxy(dict, {
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
        ownKeys: (target) => {
            keys = target.__keys__()
            return keys.concat(["__get__", "__set__", "__has__", "__keys__"])
        }
    })"""; raw=true)
    f(t; raw=true)
end
create_object_mutable(x) = create_object(raw=true)
# create_object_mutable(x) = @napi_call create_object_mutable(
#     pointer_from_objref(x)::Ptr{Cvoid}
# )::NapiValue
# create_object_immutable(x::T) where T = create_object([NapiPropertyDescriptor(
#     name = k,
#     value = getfield(x, k)
# ) for k in fieldnames(T)])
function create_object_immutable(x::T) where T
    nv = create_object(raw=true)
    for k in fieldnames(T)
        nv[string(k)] = getfield(x, k)
    end
    nv
end

const JuliaTypeCache = Dict{Ptr{Type}, Type}()
const JuliaObjectCache = Dict{Ptr{Cvoid}, Tuple{Any, NodeObject}}()
# function add_jltype(::Type{T}) where T
function add_jltype!(nv, ::Type{T}) where T
    p = Ptr{Type}(pointer_from_objref(T))
    if !haskey(JuliaTypeCache, p)
         JuliaTypeCache[p] = T
    end
    nv[_JLTYPE_PROPERTY] = UInt64(p)
    nv
end

napi_value(js_object::JsObjectType) = convert(NapiValue, getfield(js_object, :ref))
napi_value(v::DateTime) = @napi_call napi_create_date(datetime2unix(v)::Cdouble)::NapiValue
# TODO
const _JLTYPE_PROPERTY = "__jl_type"
const _JLPTR_PROPERTY = "__jl_ptr"
function napi_value(v::T; isdict=false) where T
    mut = ismutable(v)
    ptr = nothing
    if mut
        ptr = Ptr{Cvoid}(pointer_from_objref(v))
        haskey(JuliaObjectCache, ptr) && return NapiValue(JuliaObjectCache[ptr][2])
    end
    nv = if isdict
        create_object_dict(v)
    elseif mut
        create_object_mutable(v)
    else
        create_object_immutable(v)
    end
    add_jltype!(nv, T)
    if mut
        nv[_JLPTR_PROPERTY] = UInt64(ptr)
        JuliaObjectCache[ptr] = (v, node_value(nv))
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
    jltype = @napi_call napi_get_named_property(v::NapiValue, _JLTYPE_PROPERTY::Cstring)::NapiValue
    get_type(jltype) == NapiTypes.napi_undefined && return nothing
    jltype_ptr = Ptr{Type}(value(UInt64, jltype))
    T = get(JuliaTypeCache, jltype_ptr, nothing)
    isnothing(T) && return nothing
    if T.mutable
        jlobject = @napi_call napi_get_named_property(v::NapiValue, _JLPTR_PROPERTY::Cstring)::NapiValue
        get_type(jlobject) == NapiTypes.napi_undefined && return nothing
        jlobject_ptr = Ptr{Cvoid}(value(UInt64, jlobject))
        JuliaObjectCache
        if haskey(JuliaObjectCache, jlobject_ptr)
            JuliaObjectCache[jlobject_ptr][1]
        else
            nothing
        end
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

finalize_callback(f::Function) = @cfunction($f, Cvoid, (NapiEnv, Ptr{Cvoid}, Ptr{Cvoid}))

function add_finalizer!(nv::NapiValue, f, data=nothing)
    data = isnothing(data) ? C_NULL : data
    @napi_call napi_add_finalizer(
        nv::NapiValue, data::Ptr{Cvoid},
        finalize_callback(f)::NapiFinalize, C_NULL::Ptr{Cvoid}
    )::NapiRef
    nv
end
