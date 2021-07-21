struct JsFunction{T <: Union{Nothing, ValueTypes}} <: JsObjectType
    ref::NodeObject
    this::T
end
value(::Type{JsFunction}, v::NapiValue; this=nothing) = JsFunction(NodeObject(v), this)

(func::ValueTypes)(
    args...;
    recv=nothing, pass_copy=false,
    raw=false, convert_result=true
) = with_result(raw, convert_result) do
    if pass_copy
        args = deepcopy.(args)
    end
    recv = if isnothing(recv)
        if typeof(func) <: JsFunction
            this = getfield(func, :this)
            isnothing(this) ? get_global() : this
        else
            get_global()
        end
    else
        recv
    end
    argc = length(args)
    argv = argc == 0 ? C_NULL : NapiValue.(collect(args))
    @napi_call napi_call_function(
        recv::NapiValue, func::NapiValue, argc::Csize_t, argv::Ptr{NapiValue}
    )::NapiValue
end

wrap_function(f) = @cfunction($f, NapiValue, (NapiEnv, NapiCallbackInfo))

function get_callback_info(env::NapiEnv, info::NapiPointer, argc = 6)
    argv = Vector{NapiValue}(undef, argc)
    argc = Ref(argc)
    this = Ref{NapiValue}
    data = @napi_call env napi_get_cb_info(
        info::NapiPointer,
        argc::Ptr{Csize_t}, argv::Ptr{NapiValue},
        this::Ptr{NapiValue}
    )::NapiPointer
    NapiCallbackInfo(argc[], argv, this[], data)
end

function call_function(func_ptr::Ptr{Cvoid}, args_ptr::Ptr{Cvoid}, argc::Csize_t, _recv::Ptr{Cvoid})
    func = get_reference(func_ptr)
    args_ptr = Ptr{NapiValue}(args_ptr)
    args = [value(unsafe_load(args_ptr, i)) for i in 1:argc]
    NapiValue(func[](args...))
end

function_finalizer(func_ptr) = dereference(func_ptr)

function napi_value(f::Function; name=nothing)
    func_ptr = pointer(reference(f))
    name = isnothing(name) ? C_NULL : name
    nv = @napi_call create_function(func_ptr::Ptr{Cvoid}, name::Cstring)::NapiValue
    add_finalizer!(nv, function_finalizer, func_ptr)
    nv
end

# Iterators
# napi_value(v::AbstractIterator)
value(::Type{JsIterator}, v::NapiValue) = JsIterator(NodeObject(v))
function Base.iterate(v::NapiValue, state = nothing; raw=false, convert_result=true)
    iterator = isnothing(state) ? v[_JS_ITERATOR_SYMBOL[]]() : state
    state = iterator.next(raw=true)
    state.done && return nothing
    result = get(state, "value", nothing; raw=raw, convert_result=convert_result)
    result, iterator
end
Base.iterate(v::ValueTypes, state = nothing) = @with_scope iterate(NapiValue(v), state)
