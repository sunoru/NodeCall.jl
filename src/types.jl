abstract type NodeValue end
napi_env(v::NodeValue) = v.env
NodeValue(env, value) = node_value(env, value)
# Base.show(io::IO, v::NodeValue) = print(io, value(napi_env(v), String, v))

mutable struct NodeValueTemp <: NodeValue
    env::NapiEnv
    tempname::String
end

mutable struct NodeObject <: NodeValue
    env::NapiEnv
    ref::NapiRef
    function NodeObject(env, napi_ref)
        ref = new(env, napi_ref)
        finalizer(ref) do r
            @libcall r.env napi_delete_reference(r.ref::NapiRef)
        end
        ref
    end
end

NodeObject(env, value::NapiValue) = NodeObject(
    env,
    @libcall env napi_create_reference(value::NapiValue, 1::UInt32)::NapiRef
)

const JsUndefined = Nothing
const JsNull = Nothing

const JsBoolean = Bool
const JsNumber = Float64
const JsString = String
const JsBigInt = BigInt
const JsSymbol = Symbol

abstract type JsValue end

abstract type JsObject <: JsValue end

struct JsObjectValue <: JsObject
    ref::NodeObject
end

struct JsFunction <: JsObject
    ref::NodeObject
end
napi_env(v::JsObject) = napi_env(v.ref)

Base.getindex(o::Union{NodeObject, JsObject}, key; convert_result=true) = let env = napi_env(o)
    value(
        env,
        @libcall env napi_get_property(NapiValue(o)::NapiValue, NapiValue(env, key)::NapiValue)::NapiValue
    )
end
Base.setindex!(o::Union{NodeObject, JsObject}, key, value) = let env = napi_env(o)
    @libcall env napi_set_property(NapiValue(o)::NapiValue, NapiValue(env, key)::NapiValue, NapiValue(env, value)::NapiValue)::Bool
end

struct JsExternal <: JsValue
    ptr::NapiPointer
end

JsValue(env, value) = value(env, value)

const ValueTypes = Union{NapiValue, NodeValue, JsValue}
