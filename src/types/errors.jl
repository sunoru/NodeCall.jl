struct NodeError <: NodeValue
    o::NodeObject
end
NodeError(value::NapiValue) = NodeError(NodeObject(value))

Base.show(io::IO, v::NodeError) = print(io, v.message)
napi_value(node_error::NodeError) = napi_value(getfield(node_error, :o))

node_throw(err::NapiValue) = @napi_call napi_throw(err::NapiValue)
node_throw(err::Exception) = @with_scope node_throw(napi_value(err))
function node_throw(x)
    err = ErrorException(sprint(showerror, x))
    node_throw(err)
end
napi_value(err::Exception) = @napi_call napi_create_error(
    C_NULL::NapiValue, sprint(showerror, err)::NapiValue
)::NapiValue
