import Base: RefValue


struct ReferenceEntry{T}
    ref::RefValue{T}
    count::Int
end
Base.pointer(ref::ReferenceEntry{T}) where T = pointer_from_objref(T.mutable ? ref.ref[] : ref.ref)
Base.getindex(ref::ReferenceEntry) = ref.ref[]

# Objects (id) -> Pointers
const ObjectReference = IdDict{Any, RefValue}()
# Pointers -> Reference
const ReferenceCache = Dict{Ptr{Cvoid}, ReferenceEntry}()

get_reference(id::Union{UInt64, Ptr}) = get(ReferenceCache, Ptr{Cvoid}(id), nothing)

delete_reference(id::Union{UInt64, Ptr}) = delete!(ReferenceCache, Ptr{Cvoid}(id))

function reference(object::T) where T
    ref = get!(ObjectReference, object) do
        Ref(object)
    end
    ptr = Ptr{Cvoid}(pointer_from_objref(T.mutable ? object : ref))
    entry = get(ReferenceCache, ptr) do
        ReferenceEntry(ref, 0)
    end
    ReferenceCache[ptr] = ReferenceEntry(entry.ref, entry.count + 1)
end
function reference(id::Union{UInt64, Ptr})
    ptr = Ptr{Cvoid}(id)
    entry = pop!(ReferenceCache, ptr, nothing)
    isnothing(entry) && return nothing
    ReferenceCache[ptr] = ReferenceEntry(entry.ref, entry.count + 1)
end
function dereference(id::Union{UInt64, Ptr})
    ptr = Ptr{Cvoid}(id)
    entry = pop!(ReferenceCache, ptr, nothing)
    isnothing(entry) && return nothing
    ref = ReferenceEntry(entry.ref, entry.count - 1)
    if entry.count > 1
        ReferenceCache[ptr] = ref
    end
    ref
end
