const NodeContexts = Vector{NodeObject}()
const _VM = Ref{NodeObject}()
const _ASSIGN_DEFAULTS = Ref{NodeObject}()

current_context() = let i = _GLOBAL_ENV.context_index
    i == 0 ? nothing : NodeContexts[i]
end

function _initialize_context()
    _VM[] = node"require('vm')"o
    _ASSIGN_DEFAULTS[] = node"""(ctx) => Object.assign({
        console, require
    }, ctx)"""o
    new_context()
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

new_context(context_object=nothing; add_defaults=true, be_current=true) = @with_scope begin
    if isnothing(context_object)
        context_object = node"new Object()"r
    end
    if add_defaults
        context_object = _ASSIGN_DEFAULTS[](context_object; raw=true)
    end
    context = _VM[].createContext(
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
        @warn "Deleting currently activated context."
        _GLOBAL_ENV.context_index = 1
    end
    ret = deleteat!(NodeContexts, index)
    if length(NodeContexts) == 0
        new_context()
    end
    ret
end
function delete_context(context)
    for i in 1:length(NodeContexts)
        if NodeContexts[i] == context
            return delete_context(i)
        end
    end
    false
end

function context_list()

end
