function run(
    script::AbstractString;
    raw = false,
    convert_result = true
)
    script = strip(script)
    script = startswith(script, '{') ? "($script)" : script
    scope = raw ? nothing : open_scope()
    result = @napi_call napi_run_script(script::NapiValue)::NapiValue
    ret = if raw 
        result
    elseif convert_result
        value(result)
    else
        node_value(result)
    end
    close_scope(scope)
    ret
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

require(id::AbstractString) = run("globalThis.require('$(id)')")
