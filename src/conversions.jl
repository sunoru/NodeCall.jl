import Dates: DateTime, unix2datetime, datetime2unix
import UUIDs: uuid4

Base.convert(::Type{T}, v::T) where T <: ValueTypes = v
# NapiValue
macro wrap_napi_value(name, T)
    create_func = Symbol(:napi_create_, name)
    @eval napi_value(v::$T) = @napi_call $create_func(v::$T)::NapiValue
end
NapiValue(v) = napi_value(v)
Base.convert(::Type{NapiValue}, v::T) where T = NapiValue(v)
Base.convert(::Type{NapiValue}, v::ValueTypes) = NapiValue(v)
napi_value(v::NapiValue) = v
napi_value(::Nothing) = @napi_call napi_get_undefined()::NapiValue  # TODO: undefined or null?
napi_value(v::Bool) = @napi_call napi_get_boolean(v::Bool)::NapiValue
napi_value(v::Number) = @napi_call napi_create_double(Float64(v)::Float64)::NapiValue
@wrap_napi_value int32 Int32
@wrap_napi_value uint32 UInt32
@wrap_napi_value int64 Int64
@wrap_napi_value double Float64
# @wrap_napi_value bigint_int64 Int64
@wrap_napi_value bigint_uint64 UInt64
function napi_value(v::BigInt)
    sign_bit = v < 0 ? 1 : 0
    @napi_call napi_create_bigint_words(sign_bit::Cint, v.size::Csize_t, v.d::Ptr{UInt64})::NapiValue
end
napi_value(s::AbstractString) = @napi_call napi_create_string_utf8(s::Cstring, length(s)::Csize_t)::NapiValue
napi_value(s::Cstring) = napi_value(unsafe_string(s))
napi_value(node_value::NodeValueTemp) = get_tempvar(getfield(node_value, :tempname))
napi_value(node_object::NodeObject) = @napi_call napi_get_reference_value(getfield(node_object, :ref)::NapiRef)::NapiValue
napi_value(node_error::NodeError) = napi_value(getfield(node_error, :o))
napi_value(js_object::JsObjectType) = convert(NapiValue, getfield(js_object, :ref))
napi_value(s::Symbol) = @napi_call napi_create_symbol(napi_value(string(s))::NapiValue)::NapiValue
# Objects & Arrays
# napi_value(d::AbstractDict)
# napi_value(v::AbstractArray)
napi_value(v::DateTime) = @napi_call napi_create_date(datetime2unix(v)::Cdouble)::NapiValue

# NodeValue
NodeValue(v) = node_value(v)
Base.convert(::Type{NodeValue}, v::T) where T = NodeValue(v)
function node_value(
    napi_value::NapiValue;
    tempname = string(uuid4(global_rng()))
)
    t = get_type(napi_value)
    tempname
    if t ∈ (NapiTypes.napi_object, NapiTypes.napi_function)
        return NodeObject(napi_value)
    end
    tempvar = get_tempvar()
    tempvar[tempname] = napi_value
    NodeValueTemp(tempname)
end
node_value(v) = node_value(NapiValue(v))

# JsValue
JsValue(::Type{T}, v) where T = value(T, v)
JsValue(v) = value(v)
value(v) = v
value(v::ValueTypes) = @with_scope value(NapiValue(v))
Base.convert(::Type{T}, v::ValueTypes) where T = JsValue(T, v)
value(::Type{T}, v::ValueTypes) where T = @with_scope value(T, NapiValue(v))
value(::Type{T}, v::NapiValue) where T = error("Unimplemented to convert a NapiValue to $T")
value(::Type{T}, v::NapiValue) where T <: Number = T(@napi_call napi_get_value_double(v::NapiValue)::Cdouble)
value(::Type{Bool}, v::NapiValue) = @napi_call napi_get_value_bool(v::NapiValue)::Bool
value(::Type{Int32}, v::NapiValue) = @napi_call napi_get_value_int32(v::NapiValue)::Int32
value(::Type{UInt32}, v::NapiValue) = @napi_call napi_get_value_int32(v::NapiValue)::UInt32
value(::Type{Int64}, v::NapiValue; is_bigint = false) = if is_bigint
    @napi_call napi_get_value_int64(v::NapiValue)::Int64
else
    ret = Ref{Int64}()
    lossless = @napi_call napi_get_value_bigint_int64(v::NapiValue, ret::Ptr{Int64})::Bool
    ret[]
end
function value(::Type{UInt64}, v::NapiValue)
    ret = Ref{UInt64}()
    lossless = @napi_call napi_get_value_bigint_uint64(v::NapiValue, ret::Ptr{UInt64})::Bool
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
        open_scope() do _
            s = @napi_call napi_coerce_to_string(v::NapiValue)::NapiValue
            value(String, s; is_string = true)
        end
    end
end
value(::Type{Symbol}, v::NapiValue) = Symbol(v.description)
value(::Type{JsObject}, v::NapiValue) = JsObject(NodeObject(v))
value(::Type{JsFunction}, v::NapiValue) = JsFunction(NodeObject(v))
value(::Type{JsExternal}, v::NapiValue) = JsExternal(
    @napi_call napi_get_value_external(v::NapiValue)::NapiPointer
)
value(::Type{DateTime}, v::NapiValue) = open_scope() do _
    val = @napi_call napi_get_date_value(v::NapiValue)::Cdouble
    unix2datetime(val / 1000)
end
value(::Type{T}, v::NapiValue) where T <: AbstractArray = T(value(Array, v))
value(
    ::Type{Array}, v::NapiValue;
    array_type=nothing
) = if array_type == :typedarray || isnothing(array_type) && is_typedarray(v)
    info = typedarray_info(v)
    T = if info.type == NapiTypes.napi_int8_array
        Int8
    elseif info.type == NapiTypes.napi_uint8_array || info.type == NapiTypes.napi_uint8_clamped_array
        UInt8
    elseif info.type == NapiTypes.napi_int16_array
        Int16
    elseif info.type == NapiTypes.napi_uint16_array
        UInt16
    elseif info.type == NapiTypes.napi_int32_array
        Int32
    elseif info.type == NapiTypes.napi_uint32_array
        UInt32
    elseif info.type == NapiTypes.napi_float32_array
        Float32
    elseif info.type == NapiTypes.napi_float64_array
        Float64
    elseif info.type == NapiTypes.napi_bigint64_array
        Int64
    elseif info.type == NapiTypes.napi_biguint64_array
        UInt64
    else
        UInt8 # should not be here
    end
    unsafe_wrap(Array{T}, Ptr{T}(info.data), info.length)
elseif array_type == :arraybuffer || isnothing(array_type) && is_arraybuffer(v)
    info = arraybuffer_info(v)
    unsafe_wrap(Array{UInt8}, info.data, info.length)
else
    len = length(v)
    [v[i] for i in 0:len-1]
end
value(::Type{T}, v::NapiValue) where T <: AbstractDict = T(value(Dict, v))
value(::Type{Dict}, v::NapiValue) = @with_scope is_map(v) ? make_dict(v) : Dict(key=>v[key] for key in keys(v))
value(::Type{T}, v::NapiValue) where T <: AbstractSet = T(value(Set, v))
value(::Type{Set}, v::NapiValue) = @with_scope is_set(v) ? make_set(v) : Set(keys(v))


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

function typedarray_info(arr::NapiValue)
    typ = Ref{NapiTypedArrayType}()
    len = Ref{Csize_t}()
    data = Ref{Ptr{Cvoid}}()
    arraybuffer = Ref{NapiValue}()
    byte_offset = Ref{Csize_t}()
    @napi_call napi_get_typedarray_info(
        arr::NapiValue,
        typ::Ptr{NapiTypedArrayType},
        len::Ptr{Csize_t},
        data::Ptr{Ptr{Cvoid}},
        arraybuffer::Ptr{NapiValue},
        byte_offset::Ptr{Csize_t}
    )
    NapiTypedArrayInfo(typ[], len[], data[], arraybuffer[], byte_offset[])
end
function arraybuffer_info(arr::NapiValue)
    data = Ref{Ptr{Cvoid}}()
    byte_length = @napi_call napi_get_arraybuffer_info(data::Ptr{Ptr{Cvoid}})::Csize_t
    NapiArrayBufferInfo(data[], byte_length)
end

is_typedarray(v::NapiValue) = @napi_call napi_is_typedarray(v::NapiValue)::Bool
is_arraybuffer(v::NapiValue) = @napi_call napi_is_arraybuffer(v::NapiValue)::Bool

const _js_map = Ref{NodeObject}()
is_map(v::NapiValue) = instanceof(v, _js_map[])
const _js_set = Ref{NodeObject}()
is_set(v::NapiValue) = instanceof(v, _js_set[])

function object_value(v::NapiValue)
    if @napi_call napi_is_date(v::NapiValue)::Bool
        value(DateTime, v)
    elseif @napi_call napi_is_array(v::NapiValue)::Bool
        value(Array, v; array_type=:array)
    elseif is_typedarray(v)
        value(Array, v; array_type=:typedarray)
    elseif is_arraybuffer(v)
        value(Array, v; array_type=:arraybuffer)
    elseif is_map(v)
        value(Dict, v)
    elseif is_set(v)
        value(Set, v)
    else
        value(JsObject, v)
    end
end

function value(napi_value::NapiValue)
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
        value(JsFunction, napi_value)
    elseif t == NapiTypes.napi_external
        value(JsExternal, napi_value)
    elseif t == NapiTypes.napi_bigint
        value(BigInt, napi_value)
    else
        nothing
    end
end

