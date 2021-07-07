function run(
    env::NapiEnv,
    script::AbstractString;
    convert_result = true
)
    open_scope(env) do _
        script_value = NapiValue(env, script)
        result = @libcall env napi_run_script(script_value::NapiValue)::NapiValue
        if convert_result
            value(env, result)
        else
            node_value(env, result)
        end
    end
end

"""
    node"...js code..."

Evaluate the given JavaScript code string in the global scope.

Similar to `@py_str` in `PyCall.jl`, an `o` option appended to the string
indicates the return value should not be converted.
"""
macro node_str(code, options...)
    convert_result = length(options) == 1 && 'o' in options[1]
    quote
        run(global_env(), $code; convert_result=!$convert_result)
    end
end

require(env::NapiEnv, id::AbstractString) = run(env, "globalThis.require($(id))")
