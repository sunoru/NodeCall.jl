using Base: RefValue


struct ReferenceEntry{T}
    ref::RefValue{T}
    count::Int
end
Base.pointer(ref::ReferenceEntry) = _get_pointer(ref.ref)
Base.getindex(ref::ReferenceEntry) = ref.ref[]

# Objects (id) -> Pointers
const ObjectReference = IdDict{Any,RefValue}()
# Pointers -> Reference
const ReferenceCache = Dict{Ptr{Cvoid},ReferenceEntry}()

const TypedCompatibleArray{T} = Union{DenseArray{T},Base.ReinterpretArray{T},SubArray{T}}
_get_pointer(ref::RefValue{T}) where {T} = Ptr{Cvoid}(pointer_from_objref(ismutabletype(T) ? ref[] : ref))
_get_pointer(ref::RefValue{<:TypedCompatibleArray}) = Ptr{Cvoid}(pointer(ref[]))
get_reference(id::Union{UInt64,Ptr}) = get(ReferenceCache, Ptr{Cvoid}(id), nothing)

function delete_reference(id::Union{UInt64,Ptr})
    ref = pop!(ReferenceCache, Ptr{Cvoid}(id), nothing)
    if isnothing(ref)
        false
    else
        delete!(ObjectReference, ref[])
        true
    end
end

_make_ref(object) = Ref(object)
_make_ref(arr::Base.ReinterpretArray) = _make_ref(parent(arr))

function make_reference(@nospecialize(object))
    ref = get!(ObjectReference, object) do
        _make_ref(object)
    end
    ptr = _get_pointer(ref)
    entry = get(ReferenceCache, ptr) do
        ReferenceEntry(ref, 0)
    end
    ReferenceCache[ptr] = ReferenceEntry(entry.ref, entry.count + 1)
end

reference(@nospecialize(object)) = make_reference(object)
function reference(id::Union{UInt64,Ptr})
    ptr = Ptr{Cvoid}(id)
    entry = pop!(ReferenceCache, ptr, nothing)
    isnothing(entry) && return nothing
    ReferenceCache[ptr] = ReferenceEntry(entry.ref, entry.count + 1)
end

dereference(@nospecialize(object)) = initialized() && haskey(ObjectReference, object) ? dereference(
    _get_pointer(ObjectReference[object])
) : nothing
function dereference(id::Union{UInt64,Ptr})
    ptr = Ptr{Cvoid}(id)
    entry = pop!(ReferenceCache, ptr, nothing)
    isnothing(entry) && return nothing
    ref = ReferenceEntry(entry.ref, entry.count - 1)
    if entry.count > 1
        ReferenceCache[ptr] = ref
    else
        delete!(ObjectReference, ref[])
    end
    ref
end
