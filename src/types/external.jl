struct JsExternal{T} <: JsValue
    ptr::Ptr{T}
end

Base.show(io::IO, v::JsExternal) = print(io, string(typeof(v), ": ", string_pointer(getfield(v, :ptr))))

napi_value(v::JsExternal) = napi_value(UInt64(getfield(v, :ptr)))
value(::Type{JsExternal}, v::NapiValue) = JsExternal(
    @napi_call napi_get_value_external(v::NapiValue)::NapiPointer
)
