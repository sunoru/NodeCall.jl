Base.length(v::ValueTypes) = Int(@with_scope begin
    nv = NapiValue(v)
    if is_typedarray(nv)
        get_array_info(nv, :typedarray).length
    elseif is_arraybuffer(nv)
        get_array_info(nv, :arraybuffer).length
    elseif is_array(nv)
        @napi_call napi_get_array_length(nv::NapiValue)::UInt32
    else
        nv.length
    end
end)

function get_array_info(arr::NapiValue, array_type=:typedarray)
    data = Ref{Ptr{Cvoid}}()
    if array_type == :arraybuffer
        byte_length = @napi_call napi_get_arraybuffer_info(arr::NapiValue, data::Ptr{Ptr{Cvoid}})::Csize_t
        return NapiArrayBufferInfo(data[], byte_length)
    elseif array_type == :buffer
        byte_length = @napi_call napi_get_buffer_info(arr::NapiValue, data::Ptr{Ptr{Cvoid}})::Csize_t
        return NapiArrayBufferInfo(data[], byte_length)
    end

    typ = Ref{NapiTypedArrayType}()
    len = Ref{Csize_t}()
    arraybuffer = Ref{NapiValue}()
    byte_offset = Ref{Csize_t}()
    if array_type == :dataview
        @napi_call napi_get_dataview_info(
            arr::NapiValue,
            len::Ptr{Csize_t},
            data::Ptr{Ptr{Cvoid}},
            arraybuffer::Ptr{NapiValue},
            byte_offset::Ptr{Csize_t}
        )
    elseif array_type == :typedarray
        @napi_call napi_get_typedarray_info(
            arr::NapiValue,
            typ::Ptr{NapiTypedArrayType},
            len::Ptr{Csize_t},
            data::Ptr{Ptr{Cvoid}},
            arraybuffer::Ptr{NapiValue},
            byte_offset::Ptr{Csize_t}
        )
    end
    NapiTypedArrayInfo(typ[], len[], data[], arraybuffer[], byte_offset[])
end
function arraybuffer_info(arr::NapiValue)
    data = Ref{Ptr{Cvoid}}()
    byte_length = @napi_call napi_get_arraybuffer_info(arr::NapiValue, data::Ptr{Ptr{Cvoid}})::Csize_t
    NapiArrayBufferInfo(data[], byte_length)
end

function _napi_value(v::AbstractArray)
    n = length(v)
    nv = @napi_call napi_create_array_with_length(n::Csize_t)::NapiValue
    for i in 1:n
        nv[i-1] = v[i]
    end
    nv
end
# Pointer => (ArrayBuffer, ByteSize, RefCount)
const ArrayBufferCache = Dict{Ptr{Cvoid}, Tuple{NodeObject, Int, Int}}()
array_finalizer(arraybuffer) = @with_scope begin
    initialized() || return
    ptr = arraybuffer_info(napi_value(arraybuffer)).data
    haskey(ArrayBufferCache, ptr) || return
    v, byte_length, ref_count = ArrayBufferCache[ptr]
    if ref_count > 1
        ArrayBufferCache[ptr] = (v, byte_length, ref_count - 1)
    end
end
const TypedCompatibleArray{T} = Union{DenseArray{T}, Base.ReinterpretArray{T}}
function _napi_value(v::TypedCompatibleArray, typedarray_type; copy_array=false)
    isnothing(typedarray_type) && return _napi_value(v)
    T = eltype(v)
    n = length(v)
    byte_length = sizeof(T) * n
    arraybuffer = if copy_array
        data = Ref{Ptr{Cvoid}}()
        ab = @napi_call napi_create_arraybuffer(byte_length::Csize_t, data::Ptr{Ptr{Cvoid}})::NapiValue
        @ccall memcpy(data[]::Ptr{Cvoid}, v::Ptr{Cvoid}, byte_length::Csize_t)::Ptr{Cvoid}
        NodeObject(ab)
    else
        ptr = Ptr{Cvoid}(pointer(v))
        ab, byte_length2, ref_count = get(ArrayBufferCache, ptr) do
            ab = @napi_call napi_create_external_arraybuffer(
                v::Ptr{Cvoid}, byte_length::Csize_t,
                C_NULL::NapiPointer, C_NULL::NapiPointer
            )::NapiValue
            NodeObject(ab), byte_length, 0
        end
        @assert byte_length == byte_length2
        ArrayBufferCache[ptr] = (ab, byte_length, ref_count + 1)
        ab
    end
    nv = @napi_call napi_create_typedarray(
        typedarray_type::NapiTypedArrayType, n::Csize_t,
        arraybuffer::NapiValue, 0::Csize_t
    )::NapiValue
    add_finalizer!(nv, array_finalizer, arraybuffer)
    nv
end

function napi_value(
    v::TypedCompatibleArray{T};
    copy_array=false, typedarray_type=nothing
) where T
    isnothing(typedarray_type) || return _napi_value(v, typedarray_type; copy_array=copy_array)
    _napi_value(v, if T == Int8
        NapiTypes.napi_int8_array
    elseif T == UInt8 
        NapiTypes.napi_uint8_array
    elseif T == Int16
        NapiTypes.napi_int16_array
    elseif T == UInt16
        NapiTypes.napi_uint16_array
    elseif T == Int32
        NapiTypes.napi_int32_array
    elseif T == UInt32
        NapiTypes.napi_uint32_array
    elseif T == Float32
        NapiTypes.napi_float32_array
    elseif T == Float64
        NapiTypes.napi_float64_array
    elseif T == Int64
        NapiTypes.napi_bigint64_array
    elseif T == UInt64
        NapiTypes.napi_biguint64_array
    else
        nothing
    end; copy_array=copy_array)
end
napi_value(v::AbstractArray) = _napi_value(v, nothing)

napi_value(v::AbstractSet) = napi_value(collect(v))

Base.Array(v::ValueTypes) = value(Array, v)

value(::Type{T}, v::NapiValue) where T <: AbstractArray = T(value(Array, v))
value(
    ::Type{Array}, v::NapiValue;
    array_type=nothing
) = if array_type == :typedarray || isnothing(array_type) && is_typedarray(v)
    info = get_array_info(v, :typedarray)
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
    info = get_array_info(v, :arraybuffer)
    unsafe_wrap(Array{UInt8}, info.data, info.length)
elseif array_type == :buffer || isnothing(array_type) && is_buffer(v)
    info = get_array_info(v, :buffer)
    unsafe_wrap(Array{UInt8}, info.data, info.length)
elseif array_type == :dataview || isnothing(array_type) && is_dataview(v)
    info = get_array_info(v, :dataview)
    unsafe_wrap(Array{UInt8}, Ptr{UInt8}(info.data), info.length)
else
    len = length(v)
    [v[i] for i in 0:len-1]
end
