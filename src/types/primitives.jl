const JsUndefined = Nothing
const JsNull = Nothing

const JsBoolean = Bool
const JsNumber = Float64
const JsString = String
const JsBigInt = BigInt
const JsSymbol = Symbol

macro wrap_get_env(name)
    func_name = Symbol(:get_, name)
    napi_name = Symbol(:napi_, func_name)
    @eval $func_name() = @napi_call $napi_name()::NapiValue
end

get_global(context=current_context()) = if isnothing(context)
    @napi_call napi_get_global()::NapiValue
else
    napi_value(context)
end
@wrap_get_env undefined
@wrap_get_env null

macro wrap_create_napi_value(name, T)
    create_func = Symbol(:napi_create_, name)
    @eval napi_value(v::$T) = @napi_call $create_func(v::$T)::NapiValue
end
@wrap_create_napi_value int32 Int32
@wrap_create_napi_value uint32 UInt32
@wrap_create_napi_value int64 Int64
@wrap_create_napi_value double Float64
# @wrap_create_napi_value bigint_int64 Int64
@wrap_create_napi_value bigint_uint64 UInt64

napi_value(::Nothing) = get_undefined()
napi_value(v::Bool) = @napi_call napi_get_boolean(v::Bool)::NapiValue
napi_value(v::Number) = napi_value(Float64(v))
napi_value(s::AbstractString) = @napi_call napi_create_string_utf8(s::Cstring, length(s)::Csize_t)::NapiValue
napi_value(s::Char) = napi_value(string(s))
napi_value(s::Symbol) = @napi_call napi_create_symbol(napi_value(string(s))::NapiValue)::NapiValue
# napi_value(s::Symbol) = let ss = string(s)
#     @napi_call node_api_symbol_for(ss::Cstring, length(ss)::Csize_t)::NapiValue
# end
napi_value(s::Cstring) = napi_value(unsafe_string(s))
function napi_value(v::BigInt)
    sign_bit = v < 0 ? 1 : 0
    @napi_call napi_create_bigint_words(sign_bit::Cint, v.size::Csize_t, v.d::Ptr{UInt64})::NapiValue
end

macro wrap_get_value(name, T)
    napi_func = Symbol(:napi_get_value_, name)
    @eval value(::Type{$T}, v::NapiValue) = @napi_call $napi_func(v::NapiValue)::$T
end
@wrap_get_value double Float64
@wrap_get_value bool Bool
@wrap_get_value int32 Int32
@wrap_get_value uint32 UInt32

value(::Type{T}, v::NapiValue) where T <: Number = T(value(Float64, v))
value(::Type{Int64}, v::NapiValue; is_bigint = false) = if is_bigint
    ret = Ref{Int64}()
    _lossless = @napi_call napi_get_value_bigint_int64(v::NapiValue, ret::Ptr{Int64})::Bool
    ret[]
else
    @napi_call napi_get_value_int64(v::NapiValue)::Int64
end
function value(::Type{UInt64}, v::NapiValue)
    ret = Ref{UInt64}()
    _lossless = @napi_call napi_get_value_bigint_uint64(v::NapiValue, ret::Ptr{UInt64})::Bool
    ret[]
end
function value(::Type{BigInt}, v::NapiValue)
    word_count = Ref{Csize_t}()
    @napi_call napi_get_value_bigint_words(v::NapiValue, C_NULL::Ptr{Cint}, word_count::Ptr{Csize_t}, C_NULL::Ptr{UInt64})
    sign_bit = Ref{Cint}()
    words = Vector{UInt64}(undef, word_count[])
    @napi_call napi_get_value_bigint_words(v::NapiValue, sign_bit::Ptr{Cint}, word_count::Ptr{Csize_t}, words::Ptr{UInt64})
    x = reverse(reinterpret(UInt8, words))
    hex = bytes2hex(x)
    parse(BigInt, hex, base=16) * (sign_bit[] & 1 == 0 ? 1 : -1)
end
function value(::Type{String}, v::NapiValue; is_string = false)
    if is_string
        len = @napi_call napi_get_value_string_utf8(v::NapiValue, C_NULL::Ptr{Cchar}, 0::Csize_t)::Csize_t
        buf = zeros(UInt8, len + 1)
        resize!(buf, len)
        @napi_call napi_get_value_string_utf8(v::NapiValue, buf::Ptr{Cchar}, (len+1)::Csize_t)::Csize_t
        String(buf)
    else
        @with_scope begin
            s = to_string(v)
            value(String, s; is_string = true)
        end
    end
end
value(::Type{Symbol}, v::NapiValue) = Symbol(v.description)
