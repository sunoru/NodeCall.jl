@global_node_const _REQUIRE_IN_PATH = """(() => {
    const { resolve } = require('path')
    return (id, path) => require('module')
        .createRequire(resolve(path) + '/')(id)
})()"""
function require(
    id::AbstractString;
    path=nothing,
    result=RESULT_VALUE
)
    if isnothing(path)
        node_eval("globalThis.require('$(id)')", result)
    else
        _REQUIRE_IN_PATH(id, path; result=result)
    end
end

node_import(id::AbstractString; result=RESULT_VALUE) = node_eval("import('$(id)')", result)

function _import_symbol(p::Expr, sym)
    @assert p.head ≡ :call && p.args[1] ≡ :(:)
    a, b = p.args[2:3]
    quote
        $b = $sym.$a
    end
end
_import_symbol(p::Symbol, sym) = quote
    $p = $sym.$p
end
_import_symbols(id::String, imports::Symbol) = quote
    $imports = fetch(node_import($id)).default
end |> esc
function _import_symbols(id::String, imports::Expr)
    if imports.head ≡ :tuple
        ps = [_import_symbols(id, p) for p in imports.args]
        return quote
            $(ps...)
        end
    end
    @assert imports.head ≡ :braces
    sym = gensym()
    expr = quote
        $sym = node_import($id) |> fetch
    end
    for p in imports.args
        push!(expr.args, _import_symbol(p, sym))
    end
    push!(expr.args, :nothing)
    esc(expr)
end

"""
    foo = @await @node_import "foo"
    @node_import foo from "foo"
    @node_import foo, { bar: b, bar2 } from "foo"

A helper for importing a module in a JavaScript style. `:` is used instead of `as`.
"""
macro node_import(exprs...)
    len = length(exprs)
    @assert len ∈ (1, 3)
    if len == 1
        id = exprs[1]
        :(node_import($id))
    else
        @assert exprs[2] ≡ :from
        _import_symbols(exprs[3], exprs[1])
    end
end

const IMPORT_UTIL_SOURCE_TEXT = "exports.node_import = (s) => import(s)"
"""
    ensure_dynamic_import(path=pwd())

A workaround for "invalid host defined options" if directly using dynamic import.
"""
function ensure_dynamic_import(path=pwd(); context=nothing)
    tmpfile, file = "", ""
    while true
        tmpfile, io = mktemp(cleanup=true)
        close(io)
        file = joinpath(path, basename(tmpfile) * ".js")
        isfile(file) || break
    end
    mv(tmpfile, file)
    try
        write(file, IMPORT_UTIL_SOURCE_TEXT)
        f = node_eval("(file) => {
            globalThis.$(DYNAMIC_IMPORT) = require(file).node_import
        }", context=context)
        f(file, context=context)
    finally
        mv(file, tmpfile)
    end
    nothing
end
