struct JsPromise <: JsObjectType
    ref::NodeObject
end

promise_resolve(deferred) = (x) -> open_scope() do _
    @napi_call napi_resolve_deferred(deferred::NapiDeferred, x::NapiValue)
end
promise_reject(deferred) = (x) -> open_scope() do _
    @napi_call napi_reject_deferred(deferred::NapiDeferred, x::NapiValue)
end

JsPromise(f::Function) = open_scope() do _
    nv = Ref{NapiValue}()
    deferred = @napi_call napi_create_promise(nv::Ptr{NapiValue})::NapiDeferred
    @async f(
        (promise_resolve(deferred), promise_reject(deferred))
    )
    Promise(NodeObject(nv))
end

value(::Type{JsPromise}, v::NapiValue) = @with_scope JsPromise(NodeObject(v))

Base.wait(promise::ValueTypes) = open_scope() do _
    nv = NapiValue(promise)
    @assert is_promise(nv)

end
