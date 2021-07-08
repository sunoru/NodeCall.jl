function run(
    script::AbstractString;
    convert_result = true
)
    script = strip(script)
    script = startswith(script, '{') ? "($script)" : script
    open_scope() do _
        result = @napi_call napi_run_script(script::NapiValue)::NapiValue
        if convert_result
            value(result)
        else
            node_value(result)
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
    keep_raw = length(options) == 1 && 'o' in options[1]
    quote
        run($code; convert_result=!$keep_raw)
    end
end

require(id::AbstractString) = run("globalThis.require($(id))")
