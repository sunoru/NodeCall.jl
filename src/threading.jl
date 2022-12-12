const _THREADSAFE_RUNNING_SYMBOL = :JLNODE_TF_RUNNING

"""
    threadsafe_call(func, [T]; force_sync=false)

Call a zero-argument function in a threadsafe manner. You can specify the type of the return value.
"""
function threadsafe_call(@nospecialize(func::Function), T::Type=Any; force_sync=false)
    if force_sync || current_task() ≡ _GLOBAL_TASK[]
        return func()
    end
    tls = task_local_storage()
    if _THREADSAFE_RUNNING_SYMBOL ∈ keys(tls)
        return func()
    end
    tls[_THREADSAFE_RUNNING_SYMBOL] = true
    ch = Channel{T}(1)
    errch = Channel{Any}(1)
    function wrapper()
        try
            put!(ch, func())
            put!(errch, nothing)
        catch err
            put!(errch, err)
        end
        nothing
    end
    cf = pointer(reference(wrapper))
    env = node_env()
    try
        status = @ccall libjlnode.threadsafe_call(
            env::NapiTypes.NapiEnv, cf::Ptr{Cvoid}
        )::NapiTypes.NapiStatus
        if status ≢ NapiTypes.napi_ok
            throw_error(env)
        end
        err = take!(errch)
        if isnothing(err)
            take!(ch)
        else
            throw(err)
        end
    finally
        dereference(cf)
        delete!(tls, _THREADSAFE_RUNNING_SYMBOL)
    end
end

function _make_threadsafe(sym::Symbol, T)
    funcsym = esc(sym)
    T = isnothing(T) ? :Any : esc(T)
    :(
        (args...; kwargs...) -> threadsafe_call(
            () -> $funcsym(args...; kwargs...),
            $T
        )
    )
end
function _make_threadsafe(expr::Expr, T)
    if expr.head ≡ :(::)
        @assert T ≡ nothing "Please specify at most one return type"
        _make_threadsafe(expr.args[1], expr.args[2])
    else
        T = isnothing(T) ? :Any : esc(T)
        :(
            threadsafe_call(
            () -> $(esc(expr)),
            $T
        )
        )
    end
end

"""
    f2 = @threadsafe f[::T]
    result = @threadsafe f(x)[::T]

Make a function threadsafe, or call a function threadsafely. If return type is not specified, it is Any.
"""
macro threadsafe(expr)
    _make_threadsafe(expr, nothing)
end

_await(x) = fetch(x)
function _await(t::Task)
    while !istaskdone(t)
        run_node_uvloop(UV_RUN_NOWAIT)
    end
    fetch(t)
end

"""
    @await promise
    @await task

Wait and fetch the result of a `JsPromise` or `Task`. Use it for a `Task` if the `Task` calls node functions.
"""
macro await(expr, timeout=-1)
    :(_await($(esc(expr))))
end
