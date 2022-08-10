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
        _JS_WRAP_PROMISE(promise, _ -> nothing, _ -> nothing; result=RESULT_RAW)
    elseif state == promise_pending
        resolve = (x) -> begin
            setfield!(promise, :state, promise_fulfilled)
            setfield!(promise, :result, x);
        end
        reject = (x) -> begin
            setfield!(promise, :state, promise_rejected)
            setfield!(promise, :result, x);
        end
        _JS_WRAP_PROMISE(promise, resolve, reject; result=RESULT_RAW)
    end
    promise
end

@global_js_const _JS_PROMISE = "Promise"
JsPromise(f::Function) = @new _JS_PROMISE(f)

napi_value(promise::JsPromise) = convert(NapiValue, getfield(promise, :ref))
value(::Type{JsPromise}, v::NapiValue) = @with_scope JsPromise(NodeObject(v))

state(promise::JsPromise) = getfield(promise, :state)
result(promise::JsPromise) = getfield(promise, :result)
state(promise::ValueTypes) = promise_state(promise)[1]
result(promise::ValueTypes) = promise_state(promise)[2]

function promise_state(
    promise::ValueTypes;
    result=RESULT_VALUE
)
    state = Ref{PromiseState}()
    result_ = with_result(result) do
        @napi_call get_promise_state(promise::NapiValue, state::Ptr{PromiseState})::NapiValue
    end
    state[], result_
end

@global_js_const _JS_WRAP_PROMISE = """(promise, resolve, reject) => {
    const p = promise
        .then(resolve).catch(reject)
    setTimeout(() => {}, 0)
    return p
}"""
Base.fetch(
    promise::ValueTypes;
    result=RESULT_VALUE
) = with_result(result) do
    nv = NapiValue(promise)
    is_promise(nv) || return nv
    promise = value(JsPromise, nv)

    s = state(promise)
    while s == promise_pending
        run_node_uvloop(UV_RUN_ONCE)
        s = state(promise)
    end
    if s == promise_fulfilled
        return getfield(promise, :result)
    elseif s == promise_rejected
        err = getfield(promise, :result)
        err = NodeError(node_value(err))
        throw(err)
    end
end

Base.wait(promise::ValueTypes) = (fetch(promise); nothing)

@global_js_const _JS_MAKE_ASYNC = "(f) => new Promise((resolve, reject) => {
    setTimeout(() => {
        try {
            resolve(f())
        } catch (e) {
            reject(e)
        }
    }, 0)
})"
macro node_async(expr)
    letargs = Base._lift_one_interp!(expr)
    thunk = esc(:(()->($expr)))
    quote
        let $(letargs...)
            _JS_MAKE_ASYNC($thunk)
        end
    end
end
