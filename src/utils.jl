using RandomNumbers.Xorshifts: Xoshiro256StarStar

const _GLOBAL_RNG = Xoshiro256StarStar()
global_rng() = _GLOBAL_RNG


macro napi_call(env, sym)
    has_return = sym.head == :(::)
    func, result = if has_return
        sym.args[1], gensym()
    else
        sym, :status
    end
    define_vars = if has_return
        return_type = sym.args[2]
        push!(func.args, :($result::Ptr{$return_type}))
        quote
          $result = Ref{$return_type}()
        end
    else
        quote end
    end
    insert!(func.args, 2, :($env::NapiEnv))
    fname = func.args[1]
    func.args[1] = :(:libjlnode.x)
    func.args[1].args[2] = QuoteNode(fname)
    esc(quote
        $define_vars
        status = @ccall $func::NapiStatus
        if status != NapiTypes.napi_ok
            @debug status
            throw_error($env)
        end
        $result[]
    end)
end
macro napi_call(sym)
    esc(quote
        env = node_env()
        @napi_call env $sym
    end)
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
