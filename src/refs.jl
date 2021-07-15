import Base: RefValue


struct ReferenceEntry{T}
    ref::RefValue{T}
    count::Int
end

# Objects (id) -> Pointers
const ObjectReference = IdDict{Any, RefValue}()
# Pointers -> Reference
const ReferenceCache = Dict{Ptr{Cvoid}, ReferenceEntry}()

get_reference(id::Union{UInt64, Ptr}) = let entry = get(ReferenceCache, Ptr{Cvoid}(id), nothing)
    isnothing(entry) ? nothing : entry.ref[]
end
get_reference(object) = get(ObjectReference, object) do
    ObjectReference[object] = Ref(object)
end

function make_reference(object::T) where T
    ref = get_reference(object)
    ptr = pointer_from_objref(T.mutable ? object : ref)
    entry = get(ReferenceCache, ptr) do
        ReferenceEntry(ref, 0)
    end
    ReferenceCache[ptr] = ReferenceEntry(entry.ref, entry.count + 1)
    ptr
end
delete_reference(id::Union{UInt64, Ptr}) = delete!(ReferenceCache, Ptr{Cvoid}(id))

function reference(id::Union{UInt64, Ptr})
    ptr = Ptr{Cvoid}(id)
    entry = pop!(ReferenceCache, ptr, nothing)
    isnothing(entry) && return nothing
    ReferenceCache[ptr] = ReferenceEntry(entry.ref, entry.count + 1)
    entry.ref[]
end
function dereference(id::Union{UInt64, Ptr})
    ptr = Ptr{Cvoid}(id)
    entry = pop!(ReferenceCache, ptr, nothing)
    isnothing(entry) && return nothing
    if entry.count > 1
        ReferenceCache[ptr] = ReferenceEntry(entry.ref, entry.count - 1)
    end
    entry.ref[]
end
