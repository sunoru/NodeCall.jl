# Raw types from node_api.h
module NapiTypes

import Base: ==

# Types
export NapiPointer, NapiEnv, NapiValue,
    NapiRef, NapiHandleScope, NapiDeferred,
    NapiFinalize, NapiCallback,
    NapiCallbackInfo,
    NapiTypedArrayInfo,
    NapiArrayBufferInfo,
    NapiExtendedErrorInfo,
    NapiPropertyAttributes,
    NapiPropertyDescriptor
# Enums
export NapiValueType, NapiTypedArrayType, NapiStatus

abstract type AbstractNapiPointer end
primitive type NapiPointer <: AbstractNapiPointer 64 end
primitive type NapiEnv <: AbstractNapiPointer 64 end
primitive type NapiValue <: AbstractNapiPointer 64 end
Base.convert(::Type{T}, x::UInt64) where T <: Union{NapiEnv, NapiPointer} = reinterpret(T, x)
Base.convert(::Type{T}, x::AbstractNapiPointer) where T <: AbstractNapiPointer = reinterpret(T, x)
Base.convert(::Type{T}, x::NapiPointer) where T <: Ptr = reinterpret(T, x)
Base.convert(::Type{T}, x::NapiEnv) where T <: Ptr = reinterpret(T, x)
Base.convert(::Type{T}, x::NapiValue) where T <: Ptr = reinterpret(T, x)
Base.Ptr{T}(x::NapiPointer) where T = convert(Ptr{T}, x)
Base.convert(T::Type{NapiPointer}, x::Ptr) = reinterpret(T, UInt64(x))
Base.convert(T::Type{NapiEnv}, x::Ptr) = reinterpret(T, UInt64(x))
Base.convert(T::Type{NapiValue}, x::Ptr) = reinterpret(T, UInt64(x))
Base.convert(::Type{NapiPointer}, x::NapiPointer) = x
Base.convert(::Type{NapiEnv}, x::NapiEnv) = x
Base.convert(::Type{NapiValue}, x::NapiValue) = x
Base.show(io::IO, x::AbstractNapiPointer) = print(io, string(typeof(x), ": ", convert(Ptr{Nothing}, x)))
NapiPointer(x::Ptr) = convert(NapiPointer, x)
==(x::Ptr, y::AbstractNapiPointer) = x == Ptr{Nothing}(y)
const NapiRef = NapiPointer
const NapiHandleScope = NapiPointer
const NapiDeferred = NapiPointer
const NapiFinalize = Ptr{Cvoid}
const NapiCallback = Ptr{Cvoid}

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

struct NapiTypedArrayInfo
    type::NapiTypedArrayType
    length::Csize_t
    data::Ptr{Cvoid}
    arraybuffer::NapiValue
    byte_offset::Csize_t
end

struct NapiArrayBufferInfo
    data::Ptr{UInt8}
    length::Csize_t
end

struct NapiExtendedErrorInfo
    error_message::Cstring
    engine_reserved::NapiPointer
    engine_error_code::UInt32
    error_code::NapiStatus
end

@enum NapiPropertyAttributes begin
    napi_default = 0
    napi_writable = 1 << 0
    napi_enumerable = 1 << 1
    napi_configurable = 1 << 2

    napi_static = 1 << 10

    # napi_default_method = napi_writable | napi_configurable
    napi_default_method = (1 << 0) | (1 << 2)
  #   napi_default_jsproperty = napi_writable | napi_enumerable | napi_configurable
    napi_default_jsproperty = (1 << 0) | (1 << 1) | (1 << 2)
end

Base.@kwdef struct NapiPropertyDescriptor
    # One of utf8name or name should be NULL.
    utf8name::Cstring = C_NULL
    name::NapiValue = C_NULL

    method::NapiCallback = C_NULL
    getter::NapiCallback = C_NULL
    setter::NapiCallback = C_NULL

    value::NapiValue = C_NULL

    attributes::NapiPropertyAttributes = napi_default_jsproperty
    data::NapiPointer = C_NULL
end

struct NapiCallbackInfo
    argc::Csize_t
    argv::Vector{NapiValue}
    this::NapiValue
    data::NapiPointer
end

end
