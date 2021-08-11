import UUIDs: uuid4

const TEMPVAR_NAME = "__jlnode_tmp"

get_tempvar(tempname=nothing) = @with_scope begin
    temp = get(get_global(nothing), TEMPVAR_NAME; result=RESULT_RAW)
    isnothing(tempname) ? temp : temp[tempname]
end

mutable struct NodeObject <: NodeValue
    ref::NapiRef
    function NodeObject(napi_ref::NapiRef=NapiRef(C_NULL))
        nv = new(napi_ref)
        finalizer(node_value_finalizer, nv)
    end
end

NodeObject(value::NapiValue) = NodeObject(
    @napi_call napi_create_reference(value::NapiValue, 1::UInt32)::NapiRef
)
inc_ref(no::NodeObject) = @napi_call napi_reference_ref(getfield(no, :ref)::NapiRef)::UInt32
dec_ref(no::NodeObject) = @napi_call napi_reference_unref(getfield(no, :ref)::NapiRef)::UInt32
value(::Type{NodeObject}, v::NapiValue) = NodeObject(v)

mutable struct NodeValueTemp <: NodeValue
    tempname::String
    function NodeValueTemp(tempname::AbstractString="")
        nv = new(tempname)
        finalizer(node_value_finalizer, nv)
    end
end

NodeValueTemp(v::NapiValue, tempname=nothing) = @with_scope begin
    tempname = isnothing(tempname) ? string(uuid4(global_rng())) : tempname
    tempvar = get_tempvar()
    tempvar[tempname] = v
    NodeValueTemp(tempname)
end
value(::Type{NodeValueTemp}, v::NapiValue; tempname=nothing) = NodeValueTemp(v, tempname)

node_value_finalizer(v::NodeObject) = if initialized()
    ref = getfield(v, :ref)
    if ref != C_NULL
        @napi_call true napi_delete_reference(ref::NapiRef)
    end
end
node_value_finalizer(v::NodeValueTemp) = if initialized()
    t = getfield(v, :tempname)
    if t != ""
        s = @napi_call true napi_create_string_utf8(t::Cstring, length(t)::Csize_t)::NapiValue
        @napi_call true napi_delete_property(get_tempvar()::NapiValue, s::NapiValue)::Bool
    end
end

NodeValue(v; kwargs...) = node_value(v; kwargs...)
Base.convert(::Type{NodeValue}, v::T) where T = NodeValue(v)
Base.convert(::Type{NodeValue}, v::T) where T <: NodeValue = v
Base.convert(::Type{Union{Nothing, NodeValue}}, v::T) where T <: NodeValue = v
function node_value(
    nv::NapiValue;
    tempname = nothing
)
    t = get_type(nv)
    if t ∈ (NapiTypes.napi_object, NapiTypes.napi_function)
        NodeObject(nv)
    elseif t == NapiTypes.napi_external
        NodeExternal(nv)
    else
        NodeValueTemp(nv, tempname)
    end
end
node_value(v) = node_value(NapiValue(v))

Base.show(io::IO, v::NodeValueTemp) = print(io, string("NodeValueTemp: ", getfield(v, :tempname)))
Base.show(io::IO, v::NodeObject) = print(io, string("NodeObject: ", getfield(v, :ref)))

napi_value(temp::NodeValueTemp) = @napi_call napi_get_named_property(
    get_tempvar()::NapiValue,
    getfield(temp, :tempname)::Cstring
)::NapiValue
napi_value(node_object::NodeObject) = @napi_call napi_get_reference_value(
    getfield(node_object, :ref)::NapiRef
)::NapiValue
