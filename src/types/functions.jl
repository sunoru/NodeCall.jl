struct JsFunction <: JsObjectType
    ref::NodeObject
end
value(::Type{JsFunction}, v::NapiValue) = JsFunction(NodeObject(v))

function (func::ValueTypes)(args...; recv=nothing, raw=false, convert_result=true, pass_copy=false) 
    scope = raw ? nothing : open_scope()
    if pass_copy
        args = deepcopy.(args)
    end
    recv = isnothing(recv) ? get_global() : recv
    argc = length(args)
    argv = argc == 0 ? C_NULL : NapiValue.(collect(args))
    result = @napi_call napi_call_function(
        recv::NapiValue, func::NapiValue, argc::Csize_t, argv::Ptr{NapiValue}
    )::NapiValue
    result = if raw
        result
    elseif convert_result
        value(result)
    else
        node_value(result)
    end
    close_scope(scope)
    result
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
