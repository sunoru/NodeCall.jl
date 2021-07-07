import Base.convert
import UUIDs: uuid4

NapiValue(env::NapiEnv, v::T) where T = NapiValue(env, string(v)) # TODO
NapiValue(::NapiEnv, value::NapiValue) = value
NapiValue(
    env::NapiEnv,
    s::AbstractString
) = @libcall env napi_create_string_utf8(s::Cstring, length(s)::Csize_t)::NapiValue
NapiValue(
    node_value::NodeValueTemp
) = get_tempvar(node_value.env, node_value.tempname) 
NapiValue(
    node_object::NodeObject
) = @libcall node_object.env napi_get_reference_value(node_object.ref::NapiRef)::NapiValue
NapiValue(o::JsObject) = NapiValue(o.ref)

get_type(env::NapiEnv, v::NapiValue) = @libcall env napi_typeof(v::NapiValue)::NapiValueType
get_type(env::NapiEnv, v::ValueTypes) = @with_scope env get_type(env, NapiValue(v))

Base.convert(::Type{NodeValue}, v::T) where T = NodeValue(v)
# Base.convert(::Type{T}, v::NodeValue) where T = value(napi_env(v), T, v)
value(env::NapiEnv, ::Type{T}, v::NodeValue) where T = T(open_scope(_ -> value(env, T, NapiValue(env, v)), env))
value(env::NapiEnv, v::NodeValue) = open_scope(_ -> value(env, NapiValue(v)), env)

Base.convert(::Type{T}, v::NapiValue) where T = value(global_env(), T, v)
value(env::NapiEnv, ::Type{T}, v::NapiValue) where T <: Number = T(@libcall env napi_get_value_double(v::NapiValue)::Cdouble)
value(env::NapiEnv, ::Type{Bool}, v::NapiValue) = @libcall env napi_get_value_bool(v::NapiValue)::Bool
value(env::NapiEnv, ::Type{Int32}, v::NapiValue) = @libcall env napi_get_value_int32(v::NapiValue)::Int32
value(env::NapiEnv, ::Type{UInt32}, v::NapiValue) = @libcall env napi_get_value_int32(v::NapiValue)::UInt32
value(env::NapiEnv, ::Type{Int64}, v::NapiValue; is_bigint = false) = if is_bigint
    @libcall env napi_get_value_int64(v::NapiValue)::Int64
else
    ret = Ref{Int64}()
    lossless = @libcall env napi_get_value_bigint_int64(v::NapiValue, ret::Ptr{Int64})::Bool
    ret[]
end
function value(env::NapiEnv, ::Type{UInt64}, v::NapiValue)
    ret = Ref{UInt64}()
    lossless = @libcall env napi_get_value_bigint_uint64(v::NapiValue, ret::Ptr{UInt64})::Bool
    ret[]
end
function value(env::NapiEnv, ::Type{BigInt}, v::NapiValue)
    word_count = Ref{Csize_t}()
    @libcall env napi_get_value_bigint_words(v::NapiValue, C_NULL::Ptr{Cint}, word_count::Ptr{Csize_t}, C_NULL::Ptr{UInt64})
    sign_bit = Ref{Cint}()
    words = Vector{UInt64}(undef, word_count[])
    @libcall env napi_get_value_bigint_words(v::NapiValue, sign_bit::Ptr{Cint}, word_count::Ptr{Csize_t}, words::Ptr{UInt64})
    x = reverse(reinterpret(UInt8, words))
    hex = bytes2hex(x)
    parse(BigInt, hex, base=16) * (sign_bit[] & 1 == 0 ? 1 : -1)
end
function value(env::NapiEnv, ::Type{String}, v::NapiValue; is_string = false)
    if is_string
        len = @libcall env napi_get_value_string_utf8(v::NapiValue, C_NULL::Ptr{Cchar}, 0::Csize_t)::Csize_t
        buf = zeros(UInt8, len + 1)
        resize!(buf, len)
        @libcall env napi_get_value_string_utf8(v::NapiValue, buf::Ptr{Cchar}, (len+1)::Csize_t)::Csize_t
        String(buf)
    else
        open_scope(env) do _
            s = @libcall env napi_coerce_to_string(v::NapiValue)::NapiValue
            value(env, String, s; is_string = true)
        end
    end
end
value(env::NapiEnv, ::Type{Symbol}, v::NapiValue) = Symbol(value(env, String, v)[8:end-1])
value(env::NapiEnv, ::Type{JsObject}, v::NapiValue) = JsObjectValue(NodeObject(env, v))
value(env::NapiEnv, ::Type{JsFunction}, v::NapiValue) = JsFunction(NodeObject(env, v))
value(env::NapiEnv, ::Type{JsExternal}, v::NapiValue) = JsExternal(
    @libcall env napi_get_value_external(v::NapiValue)::NapiPointer
)

function value(
    env::NapiEnv,
    napi_value::NapiValue
)
    t = get_type(env, napi_value)
    if t ∈ (NapiTypes.napi_undefined, NapiTypes.napi_null)
        nothing
    elseif t == NapiTypes.napi_boolean
        value(env, Bool, napi_value)
    elseif t == NapiTypes.napi_number
        value(env, Float64, napi_value)
    elseif t == NapiTypes.napi_string
        value(env, String, napi_value; is_string = true)
    elseif t == NapiTypes.napi_symbol
        value(env, Symbol, napi_value)
    elseif t == NapiTypes.napi_object
        value(env, JsObject, napi_value)
    elseif t == NapiTypes.napi_function
        value(env, JsFunction, napi_value)
    elseif t == NapiTypes.napi_external
        value(env, JsExternal, napi_value)
    elseif t == NapiTypes.napi_bigint
        value(env, BigInt, napi_value)
    else
        nothing
    end
end

function node_value(
    env::NapiEnv,
    napi_value::NapiValue;
    tempname = string(uuid4(global_rng()))
)
    t = get_type(env, napi_value)
    if t ∈ (NapiTypes.napi_object, NapiTypes.napi_function)
        return NodeObject(env, napi_value)
    end
    tempvar = get_tempvar(env)
    tempvar[tempname] = napi_value
    NodeValueTemp(env, tempname)
end
