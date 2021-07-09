struct NodeExternal{T} <: NodeValue
    ptr::Ref{T}
    external_finalizer::Union{Nothing, Function}
end
NodeExternal(v::Ref{T}, f=nothing) where T = NodeExternal{T}(v, f)
NodeExternal(v::NapiPointer, f=nothing) = NodeExternal(Ptr{Cvoid}(v), f)
NodeExternal(v::T, f=nothing) where T = NodeExternal{T}(Ptr{T}(pointer_from_objref(v)), f)

Base.pointer(js::NodeExternal) = getfield(js, :ptr)

Base.show(io::IO, v::NodeExternal) = print(io, string(
    typeof(v), ": ", string_pointer(pointer(v))
))

node_value(v::NodeExternal) = v

function napi_value(v::NodeExternal)
    external_finalizer = getfield(v, :external_finalizer)
    callback = if isnothing(external_finalizer)
        C_NULL
    else
        @cfunction($external_finalizer, Cvoid, ())
    end
    @napi_call napi_create_external(
        pointer(v)::NapiPointer, callback::NapiFinalize, C_NULL::NapiPointer
    )::NapiValue
end
value(::Type{NodeExternal{T}}, v::NapiValue) where T = NodeExternal(
    Ptr{T}(@napi_call napi_get_value_external(v::NapiValue)::NapiPointer)
)
value(::Type{NodeExternal}, v::NapiValue) = value(NodeExternal{Cvoid}, v)
