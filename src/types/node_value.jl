import UUIDs: uuid4

const tempvar_name = "__jlnode_tmp"

_get_tempvar(tempname = nothing) = open_scope() do _
    temp = get_global()[tempvar_name]
    isnothing(tempname) ? temp : temp[tempname]
end

mutable struct NodeValueTemp <: NodeValue
    tempname::String
    function NodeValueTemp(tempname)
        nv = new(tempname)
        finalizer(nv) do v
            @with_scope delete!(_get_tempvar(), v.tempname)
        end
    end
end

NodeValueTemp(value::NapiValue, tempname=nothing) = open_scope() do _
    tempname = isnothing(tempname) ? string(uuid4(global_rng())) : tempname
    tempvar = _get_tempvar()
    tempvar[tempname] = value
    NodeValueTemp(tempname)
end

mutable struct NodeObject <: NodeValue
    ref::NapiRef
    function NodeObject(napi_ref)
        ref = new(napi_ref)
        finalizer(ref) do r
            @napi_call napi_delete_reference(getfield(r, :ref)::NapiRef)
        end
        ref
    end
end

NodeObject(value::NapiValue) = NodeObject(
    @napi_call napi_create_reference(value::NapiValue, 1::UInt32)::NapiRef
)

struct NodeError <: NodeValue
    o::NodeObject
end
NodeError(value::NapiValue) = NodeError(NodeObject(value))

NodeValue(v) = node_value(v)
Base.convert(::Type{NodeValue}, v::T) where T = NodeValue(v)
function node_value(
    napi_value::NapiValue;
    tempname = nothing
)
    t = get_type(napi_value)
    if t ∈ (NapiTypes.napi_object, NapiTypes.napi_function)
        NodeObject(napi_value)
    else
        NodeValueTemp(napi_value, tempname)
    end
end
node_value(v) = node_value(NapiValue(v))

Base.show(io::IO, v::NodeValueTemp) = print(io, string("NodeValueTemp: ", getfield(v, :tempname)))
Base.show(io::IO, v::NodeObject) = print(io, string("NodeObject: ", getfield(v, :ref)))
Base.show(io::IO, v::NodeError) = print(io, v.message)

napi_value(node_value::NodeValueTemp) = get_tempvar(getfield(node_value, :tempname))
napi_value(node_object::NodeObject) = @napi_call napi_get_reference_value(
    getfield(node_object, :ref)::NapiRef
)::NapiValue
napi_value(node_error::NodeError) = napi_value(getfield(node_error, :o))
