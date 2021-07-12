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

const JuliaFuncCache = IdDict{Base.CFunction, Function}()
# TODO: avoid ReadOnlyMemoryError.
function napi_value(f::Function; name=nothing, data=nothing)
    func = (env::NapiEnv, _info::NapiPointer) -> begin
        info = get_callback_info(env, _info)
        # f(info.argv...)
        @show info
    end
    cfunc = wrap_function(func)
    JuliaFuncCache[cfunc] = func
    name, len = if isnothing(name)
        C_NULL, 0
    else
        name, length(name)
    end
    data = isnothing(data) ? C_NULL : data
    
    nv = @napi_call napi_create_function(
        name::Cstring, len::Csize_t,
        cfunc::NapiCallback, data::Ptr{Cvoid}
    )::NapiValue
    @show nv = add_finalizer!(nv, (_env, _data, _hint) -> delete!(JuliaFuncCache, _data), cfunc)
end

# Iterators
# napi_value(v::AbstractIterator)
value(::Type{JsIterator}, v::NapiValue) = JsIterator(NodeObject(v))
function Base.iterate(v::NapiValue; raw=false, convert_result=true)
    state = v.next(raw=true)
    state.done && return nothing
    result = get(state, "value", nothing; raw=raw, convert_result=convert_result)
    result, nothing
end
Base.iterate(v::ValueTypes, state = nothing) = @with_scope iterate(NapiValue(v))
