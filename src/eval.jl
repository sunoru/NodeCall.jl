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
    node_eval(script; context=current_context(), result=RESULT_VALUE)

Evaluate the given JavaScript script in a given `context`. If `context` is `nothing`,
the script will be run in the global scope.

If `result` is set `RESULT_RAW`, the raw `napi_value` will be returned.
Note that it is only available inside current `napi_handle_scope`.
Thus, if you did't open one, the `napi_value` would remain in the global
`napi_handle_scope`.

If `result` is `RESULT_VALUE` (which is the default), the result will be converted to
the most suitable Julia type before being returned.
"""
function node_eval(
    script::AbstractString,
    result=RESULT_VALUE;
    context=current_context(),
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

const LOCALS_NAME = "__jlnode_locals"
const LOCALS_COUNTER = Ref(0)
@global_js_const _JS_CREATE_LOCALS = """(ctx, i) => {
    if (!("$LOCALS_NAME" in ctx)) {
        ctx.$LOCALS_NAME = {}
    }
    const locals = ctx.$LOCALS_NAME
    locals[i] = {}
    return locals[i]
}"""
# From pyeval.jl
const _INTERPOLATE_FSM = Dict(
    ('p', '\'') => '\'',
    ('p', '"') => '"',
    ('p', '`') => '`',
    ('\'', '\'') => 'p',
    ('"', '"') => 'p',
    ('`', '`') => 'p',
    ('p', '$') => '$',

    ('`', '$') => 'S',
    ('p', '/') => '/',
    ('/', '/') => 'c',
    ('/', '*') => 'C',
    ('c', '\n') => 'p',
    ('C', '*') => 'E',
    ('E', '*') => 'E',
    ('E', '/') => 'p',
)
# Shouldn't be used before `__init__()`.
function interpolate_code(code::AbstractString)
    LOCALS_COUNTER[] += 1
    locals_sym = "$LOCALS_NAME[$(LOCALS_COUNTER[])]"

    buf = IOBuffer()
    state = 'p'
    i = 1 # position in code
    locals = Dict{Union{String,Int},Any}()
    numlocals = 0
    js_interpolating = 0
    js_braces = 0
    while i <= lastindex(code)
        c = code[i]
        newstate = get(_INTERPOLATE_FSM, (state, c), '?')
        if newstate == '$'
            i += 1
            i > lastindex(code) && error("unexpected end of string after \$")
            interp_literal = false
            if code[i] == '$' # $$foo pastes the string foo into the Python code
                i += 1
                interp_literal = true
            end
            expr, i = Meta.parse(code, i, greedy=false)
            if interp_literal
                # need to save both the expression and the position
                # in the string where it should be interpolated
                locals[position(buf)+1] = expr
            else
                numlocals += 1
                localvar = "$locals_sym[$numlocals]"
                locals[string(numlocals)] = expr
                print(buf, localvar)
            end
        else
            if newstate == '?'
                if state == 'p'
                    if c == '{'
                        js_braces += 1
                        newstate = 'p'
                    elseif c == '}'
                        if js_braces > 0
                            js_braces -= 1
                            newstate = 'p'
                        elseif js_interpolating > 0
                            js_interpolating -= 1
                            newstate = '`'
                        else
                            error("Unexpected symbol }")
                        end
                    elseif c == '\\'
                        if i < lastindex(code)
                            i0 = nextind(code, i)
                            if code[i0] == '$'
                                c = '$'
                                i = i0
                            end
                        end
                        newstate = 'p'
                    else
                        newstate = 'p'
                    end
                elseif state == 'E'
                    newstate = 'C'
                elseif state == 'S'
                    if c == '{'
                        js_interpolating += 1
                        newstate = 'p'
                    else
                        newstate = '`'
                    end
                elseif state ∈ ('\'', '"', '`', '/', 'c', 'C')
                    newstate = state
                end
            end
            print(buf, c)
            state = newstate
            i = nextind(code, i)
        end
    end
    return String(take!(buf)), locals_sym, locals
end

"""
    node"...js code..."[options]

Evaluate the given JavaScript script in the current context.
Use `\$` to interpolate Julia variables.

Available `options`:

- `r`: Keep the result in the raw `NapiValue`.
- `o`: Do not try to convert the result into Julia values.
- `g`: Run the script in the global scope (instead of in a `vm.Context`).
- `f`: Do not delete locals after running (for the interpolated variables).

See docs for `node_eval` for details.
"""
macro node_str(code, options...)
    result, global_, keep_locals = if length(options) == 1
        o = options[1]
        if 'r' ∈ o
            RESULT_RAW
        elseif 'o' ∈ o
            RESULT_NODE
        else
            RESULT_VALUE
        end, 'g' ∈ o, 'f' ∈ o
    else
        RESULT_VALUE, false, false
    end
    context = global_ ? :(nothing) : :(current_context())
    code, locals_sym, locals = interpolate_code(code)
    counter = LOCALS_COUNTER[]
    code_expr = Expr(:call, esc(:(Base.string)))
    i0 = firstindex(code)
    for i in sort!(collect([k for k in keys(locals) if k isa Int]))
        push!(code_expr.args, code[i0:prevind(code,i)], esc(locals[i]))
        i0 = i
    end
    push!(code_expr.args, code[i0:lastindex(code)])
    filter!(locals) do (k, _)
        k isa String
    end
    has_locals = length(locals) > 0
    assign_locals = if has_locals
        exprs = quote
            locals = NodeCall._JS_CREATE_LOCALS(
                NodeCall.get_global($context), $counter;
                context=$context, result=RESULT_RAW
            )
        end
        for (k, v) in locals
            if k isa String
                push!(exprs.args, :(
                    set!(locals, $k, $(esc(v)))
                ))
            end
        end
        exprs
    else
        nothing
    end
    delete_locals = if keep_locals || !has_locals
        nothing
    else
        delete_expr = "delete $locals_sym"
        :(node_eval($delete_expr, RESULT_RAW; context=$context))
    end
    quote
        with_result($result) do
            $assign_locals
            code = $code_expr
            ret = node_eval(code, RESULT_RAW; context=$context)
            $delete_locals
            ret
        end
    end
end

require(id::AbstractString; result=RESULT_VALUE) = node_eval("globalThis.require('$(id)')", result)
