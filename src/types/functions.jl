struct JsFunction{T <: Union{Nothing, NodeValue}} <: JsObjectType
    ref::NodeObject
    this::T
end
value(::Type{JsFunction}, v::NapiValue; this=nothing) = JsFunction(
    NodeObject(v), isnothing(this) ? nothing : node_value(this)
)

(func::ValueTypes)(
    args...;
    recv=nothing, pass_copy=false,
    result=RESULT_VALUE,
    context=current_context()
) = with_result(result) do
    if pass_copy
        args = deepcopy.(args)
    end
    recv = if isnothing(recv)
        if typeof(func) <: JsFunction
            this = getfield(func, :this)
            isnothing(this) ? get_global(context) : this
        else
            get_global(context)
        end
    else
        recv
    end
    argc = length(args)
    p_ca = COPY_ARRAY[]
    if pass_copy
        COPY_ARRAY[] = true
    end
    argv = argc == 0 ? C_NULL : NapiValue.(collect(args))
    COPY_ARRAY[] = p_ca
    @napi_call napi_call_function(
        recv::NapiValue, func::NapiValue, argc::Csize_t, argv::Ptr{NapiValue}
    )::NapiValue
end

function call_function(
    func_ptr::Ptr{Cvoid},
    args_ptr::Ptr{Cvoid},
    argc::Csize_t,
    _recv::Ptr{Cvoid}
)
    func = get_reference(func_ptr)
    args_ptr = Ptr{NapiValue}(args_ptr)
    args = [value(unsafe_load(args_ptr, i)) for i in 1:argc]
    try
        NapiValue(func[](args...))
    catch e
        node_throw(e)
        nothing
    end
end

function napi_value(f::Function; name=nothing)
    func_ptr = pointer(reference(f))
    name = isnothing(name) ? C_NULL : name
    nv = @napi_call create_function(func_ptr::Ptr{Cvoid}, name::Cstring)::NapiValue
    add_finalizer!(nv, dereference, func_ptr)
    nv
end

# Iterators
# napi_value(v::AbstractIterator)
value(::Type{JsIterator}, v::NapiValue) = JsIterator(NodeObject(v))
function Base.iterate(v::NapiValue, state = nothing; result=RESULT_VALUE)
    iterator = isnothing(state) ? v[_JS_ITERATOR_SYMBOL](result=result) : state
    state = iterator.next(result=result)
    state.done && return nothing
    ret = get(state, "value", nothing; result=result)
    ret, iterator
end
Base.iterate(v::ValueTypes, state = nothing) = @with_scope iterate(NapiValue(v), state)
