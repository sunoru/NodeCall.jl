const _CURRENT_CONTEXT = Ref{NodeObject}()

const NodeContexts = Dict{String,NodeObject}()
@global_node_const _VM = "require('vm')"
@global_node_const _ASSIGN_DEFAULTS = """(() => {
    const defaults = {
        console: globalThis.console,
        process: globalThis.process
    }
    // Pass global functions
    for (const key of Object.keys(globalThis)) {
        if (key !== 'global' && !key.startsWith('_')) {
            defaults[key] = globalThis[key]
        }
    }
    // Pass all the types (the global objects whose names start with a capital letter)
    for (const key of Object.getOwnPropertyNames(globalThis)) {
        if (key[0] === key[0].toUpperCase() && !key.startsWith('_')) {
            defaults[key] = globalThis[key]
        }
    }
    return (ctx) => Object.assign(ctx, defaults)
})()"""

current_context() = _CURRENT_CONTEXT[]

get_context(key::AbstractString) = NodeContexts[key]

function switch_context(key::AbstractString)
    context = get_context(key)
    _CURRENT_CONTEXT[] = context
    context
end
function switch_context(context)
    if context ∉ values(NodeContexts)
        NodeContexts[string(uuid4())] = context
    end
    _CURRENT_CONTEXT[] = context
    context
end

new_context(key=string(uuid4()), context_object=nothing; add_defaults=true, set_current=true) = @with_scope begin
    if isnothing(context_object)
        context_object = create_object(result=RESULT_RAW)
    end
    if add_defaults
        context_object = _ASSIGN_DEFAULTS(context_object; context=nothing, result=RESULT_RAW)
    end
    context = _VM.createContext(
        context_object;
        context=nothing,
        result=RESULT_NODE
    )
    NodeContexts[key] = context
    if set_current
        switch_context(key)
    end
    context
end

function delete_context(key::AbstractString)
    if haskey(NodeContexts, key)
        context = NodeContexts[key]
        pop!(NodeContexts, key)
        if _CURRENT_CONTEXT[] == context
            @debug "Current context is being deleted."
            if length(NodeContexts) > 0
                _CURRENT_CONTEXT[] = last(collect(values(NodeContexts)))
            else
                new_context()
            end
        end
        true
    else
        false
    end
end
function delete_context(context=current_context())
    for key in keys(NodeContexts)
        if NodeContexts[key] == context
            return delete_context(key)
        end
    end
    false
end

function clear_context()
    empty!(NodeContexts)
    new_context()
    nothing
end

list_contexts() = collect(NodeContexts)
