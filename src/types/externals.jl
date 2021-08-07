using Base: RefValue, UInt64

struct NodeExternal <: NodeValue
    ptr::Ptr{Cvoid}
    NodeExternal(ptr::Ptr{Cvoid}) = new(ptr)
end

NodeExternal(v) = NodeExternal(pointer(reference(v)))
NodeExternal(nv::NapiValue) = NodeExternal(@napi_call napi_get_value_external(nv::NapiValue)::Ptr{Cvoid})

Base.pointer(v::NodeExternal) = getfield(v, :ptr)
value(v::NodeExternal) = let t = get_reference(pointer(v))
    isnothing(t) ? nothing : t[]
end

Base.show(io::IO, v::NodeExternal) = print(io, string(
    typeof(v), ": ", value(v)
))

node_value(v::NodeExternal) = v

external_finalizer(ptr::Ptr{Cvoid}) = dereference(ptr)

napi_value(v::NodeExternal) = @napi_call create_external(pointer(v)::UInt64)::NapiValue

function value(::Type{NodeExternal}, nv::NapiValue)
    e = NodeExternal(nv)
    v = value(e)
    isnothing(v) ? e : v
end
