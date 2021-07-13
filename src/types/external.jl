using Base: RefValue

mutable struct NodeExternal{T} <: NodeValue
    ref::RefValue{T}
    count::Int
end
function NodeExternal(v::RefValue{T}) where T 
    ptr = Ptr{Cvoid}(pointer_from_objref(T.mutable ? v[] : v))
    if haskey(ExternalCache, ptr)
        ne = ExternalCache[ptr]
        setfield!(ne, :count, count(ne) + 1)
        ne
    else
        ExternalCache[ptr] = NodeExternal{T}(v, 1)
    end
end
NodeExternal(v) = NodeExternal(Ref(v))
function NodeExternal(v::Ptr)
    v = Ptr{Cvoid}(v)
    get(ExternalCache, v, nothing)
end 

const ExternalCache = Dict{Ptr{Cvoid}, NodeExternal}()

function Base.pointer(js::NodeExternal{T}) where T
    ref = getfield(js, :ref)
    pointer_from_objref(T.mutable ? ref[] : ref)
end
value(v::NodeExternal) = getfield(v, :ref)[]
count(v::NodeExternal) = getfield(v, :count)

Base.show(io::IO, v::NodeExternal) = print(io, string(
    typeof(v), ": ", getfield(v, :ref)[], " (", count(v), ")"
))

node_value(v::NodeExternal) = v

function external_finalize(ptr::Ptr{Cvoid})
    ne = NodeExternal(ptr)
    isnothing(ne) && return
    setfield!(ne, :count, count(ne) - 1)
    if count(ne) == 0
        delete!(ExternalCache, data)
    end
end

napi_value(v::NodeExternal) = @napi_call create_external(pointer(v)::NapiPointer)::NapiValue
value(::Type{NodeExternal{T}}, v::NapiValue) where T = NodeExternal(
    Ptr{T}(@napi_call napi_get_value_external(v::NapiValue)::NapiPointer)
)
value(::Type{NodeExternal}, v::NapiValue) = value(NodeExternal{Cvoid}, v)
