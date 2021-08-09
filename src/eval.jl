"""
    ResultType
"""
@enum ResultType begin
    RESULT_RAW = 0
    RESULT_NODE
    RESULT_VALUE
end
function with_result(f, type::ResultType=RESULT_VALUE; this=nothing)
    scope = type == RESULT_RAW ? nothing : open_scope()
    result = f()
    ret = if type == RESULT_RAW
        isnothing(result) ? get_undefined() : result
    elseif type == RESULT_NODE
        node_value(result)
    else
        value(result; this=this)
    end
    close_scope(scope)
    ret
end

"""
    run_script(script; context=current_context(), result=RESULT_VALUE)

Evaluate the given JavaScript script in a given `context`. If `context` is `nothing`,
the script will be run in the global scope.

If `result` is set `RESULT_RAW`, the raw `napi_value` will be returned.
Note that it is only available inside current `napi_handle_scope`.
Thus, if you did't open one, the `napi_value` would remain in the global
`napi_handle_scope`.

If `result` is `RESULT_VALUE` (which is the default), the result will be converted to
the most suitable Julia type before being returned.
"""
function run_script(
    script::AbstractString,
    result=RESULT_VALUE;
    context = current_context(),
)
    script = strip(script)
    script = if startswith(script, '{')
        "($script)"
    else
        script
    end
    if isnothing(context)
        with_result(result) do
            @napi_call napi_run_script(script::NapiValue)::NapiValue
        end
    else
        _VM.runInContext(
            script, context;
            result=result
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
    result = if length(options) == 1
        if 'r' ∈ options[1]
            RESULT_RAW
        elseif 'o' ∈ options[1]
            RESULT_NODE
        else
            RESULT_VALUE
        end
    else
        RESULT_VALUE
    end
    :(run_script($code, $result))
end

require(id::AbstractString) = run_script("globalThis.require('$(id)')")
