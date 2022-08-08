require(id::AbstractString; result=RESULT_VALUE) = node_eval("globalThis.require('$(id)')", result)

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
    @node_import { foo: foo2, bar } from "foo"

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
function ensure_dynamic_import(path=pwd())
    tmpfile, file = "", ""
    while true
        tmpfile, io = mktemp(cleanup=true)
        close(io)
        file = joinpath(path, basename(tmpfile) * ".js")
        isfile(file) || break
    end
    mv(tmpfile, file)
    write(file, IMPORT_UTIL_SOURCE_TEXT)
    node_eval("(() => {globalThis.$(DYNAMIC_IMPORT) = require('$(file)').node_import})()", context=nothing)
    mv(file, tmpfile)
    nothing
end
