@enum PromiseState begin
    promise_pending = 0
    promise_fulfilled
    promise_rejected
end

mutable struct JsPromise <: JsObjectType
    ref::NodeObject
    state::PromiseState
    result::Any
end
JsPromise(ref::NodeObject) = @with_scope begin
    promise = JsPromise(ref, promise_pending, nothing)
    state, result = promise_state(promise)
    setfield!(promise, :state, state)
    setfield!(promise, :result, result)
    if state == promise_rejected
        _JS_MAKE_PROMISE[](promise, _ -> nothing, _ -> nothing; raw=true)
    elseif state == promise_pending
        resolve = (x) -> begin
            setfield!(promise, :state, promise_fulfilled)
            setfield!(promise, :result, x);
        end
        reject = (x) -> begin
            setfield!(promise, :state, promise_rejected)
            setfield!(promise, :result, x);
        end
        _JS_MAKE_PROMISE[](promise, resolve, reject; raw=true)
    end
    promise
end

promise_resolve(deferred) = (x) -> @with_scope begin
    @napi_call napi_resolve_deferred(deferred::NapiDeferred, x::NapiValue)
end
promise_reject(deferred) = (x) -> @with_scope begin
    @napi_call napi_reject_deferred(deferred::NapiDeferred, x::NapiValue)
end

JsPromise(f::Function) = @with_scope begin
    nv = Ref{NapiValue}()
    deferred = @napi_call napi_create_promise(nv::Ptr{NapiValue})::NapiDeferred
    @async f((promise_resolve(deferred), promise_reject(deferred)))
    JsPromise(NodeObject(nv))
end

napi_value(promise::JsPromise) = convert(NapiValue, getfield(promise, :ref))
value(::Type{JsPromise}, v::NapiValue) = @with_scope JsPromise(NodeObject(v))

state(promise::JsPromise) = getfield(promise, :state)
result(promise::JsPromise) = getfield(promise, :result)
state(promise::ValueTypes) = promise_state(promise)[1]
result(promise::ValueTypes) = promise_state(promise)[2]

function promise_state(
    promise::ValueTypes;
    raw=false, convert_result=true
)
    state = Ref{PromiseState}()
    result = with_result(raw, convert_result) do
        @napi_call get_promise_state(promise::NapiValue, state::Ptr{PromiseState})::NapiValue
    end
    state[], result
end

const _JS_MAKE_PROMISE = Ref{NodeObject}()
Base.fetch(
    promise::ValueTypes;
    raw=false, convert_result=true
) = with_result(raw, convert_result) do
    nv = NapiValue(promise)
    is_promise(nv) || return nv
    promise = value(JsPromise, nv)

    s = state(promise)
    while s == promise_pending
        run_node_uvloop(UV_RUN_ONCE)
        s = state(promise)
    end
    if s == promise_fulfilled
        return result(promise)
    elseif s == promise_rejected
        throw(result(promise))
    end
end

Base.wait(promise::ValueTypes) = (fetch(promise); nothing)

macro await(expr)
    esc(:(fetch($expr)))
end
