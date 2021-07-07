module NodeCall

include("napi_types.jl")
include("utils.jl")

export NodeEnvironment
include("env.jl")

export NapiValue, JsUndefined, JsNull, JsBoolean, JsNumber, JsString, JsBigInt, JsSymbol, JsObject, JsFunction
include("types.jl")

export value, node_value
include("conversions.jl")

export run, @node_str, require
include("eval.jl")

include("defaults.jl")

end # module
