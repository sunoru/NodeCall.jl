module NodeCall

include("napi_types.jl")
using .NapiTypes

include("utils.jl")

export run, @node_str, require
include("eval.jl")

export NapiValue, NodeValue, JsValue,
       NodeValueTemp, NodeObject,
       JsUndefined, JsNull, JsBoolean, JsNumber, JsString, JsBigInt, JsSymbol,
       JsObject, JsFunction
export set!, instanceof
include("types.jl")

export value, node_value
include("conversions.jl")

export global_env
include("env.jl")

end # module
