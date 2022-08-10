function _napi_call(expr, env = nothing; force_sync=false)
    define_vars = if env ≡ nothing
        env = :env
        quote
            env = node_env()
        end
    else
        quote end
    end
    has_return = expr.head ≡ :(::)
    invocation_expr, result_sym = if has_return
        expr.args[1], gensym()
    else
        expr, :(status)
    end
    fname = QuoteNode(invocation_expr.args[1])
    args = invocation_expr.args[2:end]
    argtypes = :((NapiEnv,))
    for arg in args
        @assert arg.head ≡ :(::) "Every argument should have a type"
        push!(argtypes.args, arg.args[2])
    end
    ccall_func = :(ccall(($fname, :libjlnode), NapiStatus, $argtypes, $env))
    for arg in args
        push!(ccall_func.args, esc(arg.args[1]))
    end

    if has_return
        result_type = esc(expr.args[2])
        push!(ccall_func.args[4].args, :(Ptr{$result_type}))
        push!(ccall_func.args, result_sym)
        push!(define_vars.args, :($result_sym = Ref{$result_type}()))
    end

    quote
        let
            $define_vars
            status = $ccall_func
            if status ≢ NapiTypes.napi_ok
                @debug status
                throw_error($env)
            end
            $result_sym[]
        end
    end
end

macro napi_call(env, expr)
    _napi_call(expr, esc(env))
end

macro napi_call(expr)
    _napi_call(expr)
end

function throw_error(env::NapiEnv = node_env())
    info = @napi_call env napi_get_last_error_info()::Ptr{NapiExtendedErrorInfo}
    is_exception_pending = @napi_call env napi_is_exception_pending()::Bool
    err = if is_exception_pending
        @napi_call env napi_get_and_clear_last_exception()::NapiValue
    else
        error_info = unsafe_load(info)
        message = NapiValue(
            error_info.error_message == C_NULL ? "Error in native callback" : error_info.error_message
        )
        if error_info.error_code ∈ (
            NapiTypes.napi_object_expected,
            NapiTypes.napi_string_expected,
            NapiTypes.napi_boolean_expected,
            NapiTypes.napi_number_expected
        )
            @napi_call env napi_create_type_error(C_NULL::NapiValue, message::NapiValue)::NapiValue
        else
            @napi_call env napi_create_error(C_NULL::NapiValue, message::NapiValue)::NapiValue
        end
    end
    throw(NodeError(err))
end

const _SCOPE_STACK = Set{NapiHandleScope}()

function open_scope()
    if length(_SCOPE_STACK) < 2
        scope = @napi_call napi_open_handle_scope()::NapiHandleScope
        push!(_SCOPE_STACK, scope)
        scope
    end
end

close_scope(scope::Union{Nothing, NapiHandleScope}) = if !isnothing(scope)
    @napi_call napi_close_handle_scope(scope::NapiHandleScope)
    pop!(_SCOPE_STACK, scope)
end

function open_scope(f)
    scope = open_scope()
    try
        return f(scope)
    finally
        close_scope(scope)
    end
end
macro with_scope(code)
    esc(:(open_scope() do _
        $code
    end))
end

string_pointer(ptr::Ptr) = string("0x", string(UInt64(ptr), base = 16))
string_pointer(o) = string_pointer(pointer_from_objref(o))
