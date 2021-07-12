function with_result(f, raw::Bool, convert_result::Bool; this=nothing)
    scope = raw ? nothing : open_scope()
    result = f()
    ret = if raw
        isnothing(result) ? get_undefined() : result
    elseif convert_result
        value(result; this=this)
    else
        node_value(result)
    end
    close_scope(scope)
    ret
end

function run(
    script::AbstractString;
    raw = false,
    convert_result = true
)
    script = strip(script)
    script = if startswith(script, '{')
        "($script)"
    else
        script
    end
    with_result(raw, convert_result) do
        @napi_call napi_run_script(script::NapiValue)::NapiValue
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

require(id::AbstractString) = run("globalThis.require('$(id)')")
