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

"""
    run_script(script; context=current_context(), raw=false, convert_result=true)

Evaluate the given JavaScript script in a given `context`. If `context` is `nothing`,
the script will be run in the global scope.

If `raw` is set `true`, the raw `napi_value` will be returned.
Note that it is only available inside current `napi_handle_scope`.
Thus, if you did't open one, the `napi_value` would remain in the global
`napi_handle_scope`.

If `convert_result` is `true` (which is the default), the result will be converted to
the most suitable Julia type before being returned.
"""
function run_script(
    script::AbstractString;
    context = current_context(),
    raw = false,
    convert_result = true
)
    script = strip(script)
    script = if startswith(script, '{')
        "($script)"
    else
        script
    end
    if isnothing(context)
        with_result(raw, convert_result) do
            @napi_call napi_run_script(script::NapiValue)::NapiValue
        end
    else
        _VM.runInContext(
            script, context;
            raw=raw,
            convert_result=convert_result
        )
    end
end

"""
    node"...js code..."

Evaluate the given JavaScript script in the current context.

Similar to `@py_str` in `PyCall.jl`, an `o` option appended to the string
indicates the return value should not be converted.

You can also use `r` option to keep the raw return value as `napi_value`.

See docs for `run_script` for details.
"""
macro node_str(code, options...)
    raw, convert_result = if length(options) == 1
        'r' ∈ options[1], 'o' ∉ options[1]
    else
        false, true
    end
    quote
        run_script($code; raw=$raw, convert_result=$convert_result)
    end
end

require(id::AbstractString) = run_script("globalThis.require('$(id)')")
