using RandomNumbers.Xorshifts: Xoshiro256StarStar

const _GLOBAL_RNG = Xoshiro256StarStar()
global_rng() = _GLOBAL_RNG


macro libcall(env, sym)
    has_return = sym.head == :(::)
    func, result = if has_return
        sym.args[1], gensym()
    else
        sym, :status
    end
    check_error_block = if env == :nothing
        :(@assert status == NapiTypes.napi_ok)
    else
        insert!(func.args, 2, :($env::NapiEnv))
        :(if status != NapiTypes.napi_ok
            throw_error($env)
        end)
    end
    define_result = if has_return
        return_type = sym.args[2]
        push!(func.args, :($result::Ptr{$return_type}))
        :($result = Ref{$return_type}())
    else
        :()
    end
    fname = func.args[1]
    func.args[1] = :(:libjlnode.x)
    func.args[1].args[2] = QuoteNode(fname)
    esc(quote
        $define_result
        status = @ccall $func::NapiStatus
        $check_error_block
        $result[]
    end)
end
macro libcall(sym)
    :(@libcall nothing $sym)
end

function throw_error(env::NapiEnv)
    info = @libcall env napi_get_last_error_info()::Ptr{NapiExtendedErrorInfo}
    is_exception_pending = @libcall env napi_is_exception_pending()::Bool
    err = if is_exception_pending
        @libcall env napi_get_and_clear_last_exception()::NapiValue
    else
        error_info = unsafe_load(info)
        message = NapiValue(
            env,
            error_info.error_message == C_NULL ? "Error in native callback" : error_info.error_message
        )
        if error_info.error_code ∈ (
            NapiTypes.napi_object_expected,
            NapiTypes.napi_object_expected,
            NapiTypes.napi_string_expected,
            NapiTypes.napi_boolean_expected,
            NapiTypes.napi_number_expected
        )
            @libcall env napi_create_type_error(C_NULL::NapiValue, message::NapiValue)::NapiValue
        else
            @libcall env napi_create_error(C_NULL::NapiValue, message::NapiValue)::NapiValue
        end
    end
    throw(NodeObject(env, err))
end

const _SCOPE_STACK = Set{NapiHandleScope}()

function open_scope(env::NapiEnv)
    if length(_SCOPE_STACK) < 2
        scope = @libcall env napi_open_handle_scope()::NapiHandleScope
        push!(_SCOPE_STACK, scope)
        scope
    end
end
function close_scope(env::NapiEnv, scope::Union{Nothing, NapiHandleScope})
    if !isnothing(scope)
        @libcall env napi_close_handle_scope(scope::NapiHandleScope)
        pop!(_SCOPE_STACK, scope)
    end
end

function open_scope(f, env::NapiEnv)
    scope = open_scope(env)
    ret = f(scope)
    close_scope(env, scope)
    ret
end
macro with_scope(env, code)
    :(open_scope($env) do _
        $code
    end)
end

_get_global(env::NapiEnv) = @libcall env napi_get_global()::NapiValue
get_global(env::NapiEnv) = ObjectReference(env, _get_global(env))
const tempvar_name = "__jlnode_tmp"
get_tempvar(env::NapiEnv, tempname = nothing) = open_scope(env) do _
    _global = _get_global(env)
    temp = JsObjectValue(NodeObject(
        env,
        @libcall env napi_get_property(_global::NapiValue, NapiValue(env, tempvar_name)::NapiValue)::NapiValue
    ))
    isnothing(tempname) ? temp : temp[tempname]
end
