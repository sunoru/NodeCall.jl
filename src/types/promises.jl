# TODO: Implement promise.
struct JsPromise <: JsObjectType
    ref::NodeObject
    deferred::NapiDeferred
end

value(::Type{JsPromise}, v::NapiValue) = @with_scope JsPromise(NodeObject(v), C_NULL)
