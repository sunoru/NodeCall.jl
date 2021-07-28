struct JsPromise <: JsObjectType
    ref::NodeObject
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
    Promise(NodeObject(nv))
end

value(::Type{JsPromise}, v::NapiValue) = @with_scope JsPromise(NodeObject(v))

@enum PromiseState begin
    promise_pending = 0
    promise_fulfilled
    promise_rejected
end
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
    # cond = Condition()
    # resolve = (x...) -> notify(cond, x)
    # reject = (x...) -> notify(cond, x; error=true)

    state, result = promise_state(promise)
    if state == promise_fulfilled
        return result
    elseif state == promise_rejected
        throw(result)
    end
    success = Ref{Union{Nothing, Bool}}(nothing)
    result = Ref{Any}(nothing)
    resolve = (x) -> (success[] = true; result[] = x)
    reject = (x) -> (success[] = false; result[] = x)

    _JS_MAKE_PROMISE[](nv, resolve, reject)
    # wait(cond)

    while isnothing(success[])
        run_node_uvloop(UV_RUN_ONCE)
    end

    if success[]
        result[]
    else
        throw(result[])
    end
end

Base.wait(promise::ValueTypes) = (fetch(promise); nothing)

macro await(expr)
    esc(:(fetch($expr)))
end
