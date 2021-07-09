struct JsFunction <: JsObjectType
    ref::NodeObject
end
value(::Type{JsFunction}, v::NapiValue) = JsFunction(NodeObject(v))

(func::ValueTypes)(args...; recv=nothing, convert_result=true, pass_copy=false) = open_scope() do _
    if pass_copy
        args = deepcopy.(args)
    end
    recv = isnothing(recv) ? get_global() : recv
    argc = length(args)
    argv = argc == 0 ? C_NULL : NapiValue.(collect(args))
    result = @napi_call napi_call_function(
        recv::NapiValue, func::NapiValue, argc::Csize_t, argv::Ptr{NapiValue}
    )::NapiValue
    convert_result ? value(result) : node_value(result)
end
