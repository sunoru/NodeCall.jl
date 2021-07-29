import Base: ==

using .NapiTypes: NapiValue
abstract type NodeValue end
abstract type JsValue end
abstract type JsObjectType <: JsValue end

const ValueTypes = Union{NapiValue, NodeValue, JsValue}

Base.convert(::Type{T}, v::T) where T <: ValueTypes = v
Base.convert(::Type{NapiValue}, v::T) where T = NapiValue(v)
Base.convert(::Type{NapiValue}, v::ValueTypes) = NapiValue(v)
NapiValue(v) = napi_value(v)
napi_value(v::NapiValue) = v

==(a::ValueTypes, b::ValueTypes) = @with_scope try
    @napi_call napi_strict_equals(a::NapiValue, b::NapiValue)::Bool
catch _
    false
end

JsValue(v; this=nothing) = value(v; this=this)
value(v; this=nothing) = v
value(v::ValueTypes; this=nothing) = @with_scope value(NapiValue(v), this=this)
JsValue(::Type{T}, v) where T = value(T, v)
Base.convert(::Type{Any}, v::ValueTypes) = v
Base.convert(::Type{T}, v::ValueTypes) where T = value(T, v)
value(::Type{T}, v::ValueTypes) where T = @with_scope value(T, NapiValue(v))
value(::Type{T}, v::NapiValue) where T = error("Unimplemented to convert a NapiValue to $T")

function value(napi_value::NapiValue; this=nothing)
    t = get_type(napi_value)
    if t ∈ (NapiTypes.napi_undefined, NapiTypes.napi_null)
        nothing
    elseif t == NapiTypes.napi_boolean
        value(Bool, napi_value)
    elseif t == NapiTypes.napi_number
        value(Float64, napi_value)
    elseif t == NapiTypes.napi_string
        value(String, napi_value; is_string = true)
    elseif t == NapiTypes.napi_symbol
        value(Symbol, napi_value)
    elseif t == NapiTypes.napi_object
        object_value(napi_value)
    elseif t == NapiTypes.napi_function
        value(JsFunction, napi_value, this=this)
    elseif t == NapiTypes.napi_external
        value(NodeExternal, napi_value)
    elseif t == NapiTypes.napi_bigint
        value(BigInt, napi_value)
    else
        nothing
    end
end

# For being called in C++ code.
@noinline napi_value_from_value(v) = napi_value(v)
@noinline napi_value_to_value(nv::Ptr{Nothing}) = value(convert(NapiValue, nv))
@noinline jlnode_setindex!(o, v, k) = try
    setindex!(o, v, k)
    v
catch
    nothing
end
@noinline jlnode_getproperty(o, k) = try
    getproperty(o, Symbol(k))
catch
    nothing
end
@noinline jlnode_setproperty!(o, k, v) = try
    setproperty!(o, Symbol(k), v)
catch
    nothing
end
