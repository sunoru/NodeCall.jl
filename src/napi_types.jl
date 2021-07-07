# Raw types from node_api.h
module NapiTypes

# Types
export NapiPointer, NapiEnv, NapiValue,
    NapiRef, NapiHandleScope,
    NapiExtendedErrorInfo
# Enums
export NapiValueType, NapiTypedArrayType, NapiStatus

abstract type AbstractNapiPointer end
primitive type NapiPointer <: AbstractNapiPointer 64 end
primitive type NapiEnv <: AbstractNapiPointer 64 end
primitive type NapiValue <: AbstractNapiPointer 64 end
Base.convert(::Type{T}, x::UInt64) where T <: AbstractNapiPointer = reinterpret(T, x)
Base.convert(::Type{T}, x::Ptr) where T <: AbstractNapiPointer = reinterpret(T, UInt64(x))
Base.convert(::Type{T}, x::AbstractNapiPointer) where T <: AbstractNapiPointer = reinterpret(T, x)
Base.convert(::Type{NapiPointer}, x::NapiPointer) = x
Base.convert(::Type{NapiEnv}, x::NapiEnv) = x
Base.convert(::Type{NapiValue}, x::NapiValue) = x
Base.show(io::IO, x::AbstractNapiPointer) = print(io, reinterpret(UInt64, x))
const NapiRef = NapiPointer
const NapiHandleScope = NapiPointer

@enum NapiValueType begin
    napi_undefined
    napi_null
    napi_boolean
    napi_number
    napi_string
    napi_symbol
    napi_object
    napi_function
    napi_external
    napi_bigint
end

@enum NapiTypedArrayType begin
    napi_int8_array
    napi_uint8_array
    napi_uint8_clamped_array
    napi_int16_array
    napi_uint16_array
    napi_int32_array
    napi_uint32_array
    napi_float32_array
    napi_float64_array
    napi_bigint64_array
    napi_biguint64_array
end

@enum NapiStatus begin
    napi_ok
    napi_invalid_arg
    napi_object_expected
    napi_string_expected
    napi_name_expected
    napi_function_expected
    napi_number_expected
    napi_boolean_expected
    napi_array_expected
    napi_generic_failure
    napi_pending_exception
    napi_cancelled
    napi_escape_called_twice
    napi_handle_scope_mismatch
    napi_callback_scope_mismatch
    napi_queue_full
    napi_closing
    napi_bigint_expected
    napi_date_expected
    napi_arraybuffer_expected
    napi_detachable_arraybuffer_expected
    napi_would_deadlock
end
Base.getindex(status::NapiStatus) = status

struct NapiExtendedErrorInfo
    error_message::Cstring
    engine_reserved::NapiPointer
    engine_error_code::UInt32
    error_code::NapiStatus
end

end
