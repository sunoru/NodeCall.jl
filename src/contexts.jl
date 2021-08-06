const NodeContexts = Vector{NodeObject}()
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

current_context() = let i = _GLOBAL_ENV.context_index
    i == 0 ? nothing : NodeContexts[i]
end

function get_context(index::Integer)
    @assert 1 ≤ index ≤ length(NodeContexts)
    NodeContexts[index]
end

function switch_context(index::Integer)
    context = get_context(index)
    _GLOBAL_ENV.context_index = index
    context
end
function switch_context(context)
    for i in 1:length(NodeContexts)
        if NodeContexts[i] == context
            return switch_context(i)
        end
    end
    push!(NodeContexts, context)
    switch_context(length(NodeContexts))
end

new_context(context_object=nothing; add_defaults=true, be_current=true) = @with_scope begin
    if isnothing(context_object)
        context_object = create_object()
    end
    if add_defaults
        context_object = _ASSIGN_DEFAULTS(context_object; raw=true)
    end
    context = _VM.createContext(
        context_object;
        convert_result=false
    )
    push!(NodeContexts, context)
    if be_current
        switch_context(length(NodeContexts))
    end
    context
end

function delete_context(index::Integer=_GLOBAL_ENV.context_index)
    if _GLOBAL_ENV.context_index == index
        _GLOBAL_ENV.context_index = length(NodeContexts) == 1 ? 0 : 1
    end
    deleteat!(NodeContexts, index)
    if length(NodeContexts) == 0
        new_context()
    end
    true
end
function delete_context(context)
    for i in 1:length(NodeContexts)
        if NodeContexts[i] == context
            return delete_context(i)
        end
    end
    false
end

function clear_context() 
    _GLOBAL_ENV.context_index = 0
    resize!(NodeContexts, 0)
    new_context()
    nothing
end

list_contexts() = copy(NodeContexts)
