const NodeContexts = Dict{String, NodeObject}()
@global_js_const _VM = "require('vm')"
@global_js_const _ASSIGN_DEFAULTS = """(() => {
    const keys = ['console']
    // Pass global functions
    for (const key of Object.keys(globalThis)) {
        if (key !== 'global' && !key.startsWith('_')) {
            keys.push(key)
        }
    }
    // Pass all the types (the global objects whose names start with a capital letter)
    for (const key of Object.getOwnPropertyNames(globalThis)) {
        if (key[0] === key[0].toUpperCase() && !key.startsWith('_')) {
            keys.push(key)
        }
    }
    return (ctx) => {
        const defaults = new Object()
        for (const key of keys) {
            defaults[key] = globalThis[key]
        }
        return Object.assign(defaults, ctx)
    }
})()"""

current_context() = _GLOBAL_ENV.current_context

get_context(key::AbstractString) = NodeContexts[key]

function switch_context(key::AbstractString)
    context = get_context(key)
    _GLOBAL_ENV.current_context = context
    context
end
function switch_context(context)
    if context ∉ values(NodeContexts)
        NodeContexts[string(uuid4())] = context
    end
    _GLOBAL_ENV.current_context = context
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
        if _GLOBAL_ENV.current_context == context
            @debug "Current context is being deleted"
            if length(NodeContexts) > 0
                _GLOBAL_ENV.current_context = last(collect(values(NodeContexts)))
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
