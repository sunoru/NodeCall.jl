mutable struct ThreadSafeFunction
    ctx::Ptr{Cvoid}
    ThreadSafeFunction(ctx::Ptr{Cvoid}) = new(ctx)
end

make_thread_safe_function(
    js_func::NapiValue, this::NapiValue, name::AbstractString
) = @napi_call create_thread_safe_function(js_func::NapiValue, this::NapiValue, name::Cstring)::Ptr{Cvoid}

ThreadSafeFunction(js_func::JsFunction) = @with_scope ThreadSafeFunction(
    js_func, this = getfield(js_func, :this)
)
ThreadSafeFunction(js_func::NapiValue; this=C_NULL) = ThreadSafeFunction(
    make_thread_safe_function(js_func, NapiValue(this), "tsfn")
)
ThreadSafeFunction(
    js_func::ValueTypes; this=nothing
) = @with_scope ThreadSafeFunction(
    napi_value(js_func);
    this=isnothing(this) ? C_NULL : napi_value(this)
)

get_promise(tsfn::ThreadSafeFunction) = @napi_call get_thread_safe_promise(tsfn.ctx::Ptr{Cvoid})::NapiValue

function (f::ThreadSafeFunction)(args...)
    ctx = f.ctx
    args = [napi_value(x) for x in args]
    # promise = get_promise(tsfn)
    result = @napi_call call_thread_safe_function(ctx::Ptr{Cvoid}, args::Vector{NapiValue})::NapiRef
    @show result
    dereference(result)
end
