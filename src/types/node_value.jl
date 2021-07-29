import UUIDs: uuid4

const tempvar_name = "__jlnode_tmp"

get_tempvar(tempname=nothing) = @with_scope begin
    temp = get(get_global(nothing), tempvar_name; convert_result=false)
    isnothing(tempname) ? temp : temp[tempname]
end

mutable struct NodeObject <: NodeValue
    ref::NapiRef
    function NodeObject(napi_ref::NapiRef)
        ref = new(napi_ref)
        finalizer(ref) do r
            if initialized()
                @napi_call napi_delete_reference(getfield(r, :ref)::NapiRef)
            end
        end
        ref
    end
end

NodeObject(value::NapiValue) = NodeObject(
    @napi_call napi_create_reference(value::NapiValue, 1::UInt32)::NapiRef
)

mutable struct NodeValueTemp <: NodeValue
    tempname::String
    function NodeValueTemp(tempname::AbstractString)
        nv = new(tempname)
        finalizer(nv) do v
            if initialized()
                @with_scope delete!(get_tempvar(), getfield(v, :tempname))
            end
        end
    end
end

NodeValueTemp(v::NapiValue, tempname=nothing) = @with_scope begin
    tempname = isnothing(tempname) ? string(uuid4(global_rng())) : tempname
    tempvar = get_tempvar()
    tempvar[tempname] = v
    NodeValueTemp(tempname)
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
