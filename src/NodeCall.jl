module NodeCall

include("napi_types.jl")
using .NapiTypes

include("utils.jl")

export EnvironmentConfig
include("env.jl")

export NodeValueTemp, NodeObject, JsUndefined, JsNull, JsBoolean, JsNumber, JsString, JsBigInt, JsSymbol, JsObject, JsFunction
include("types.jl")

export value, node_value
include("conversions.jl")

export run, @node_str, require
include("eval.jl")

include("defaults.jl")

end # module
