module NodeCall

include("types/napi_types.jl")
using .NapiTypes

include("utils.jl")

export run, @node_str, require
include("eval.jl")

export NapiValue, NodeValue, JsValue,
       NodeValueTemp, NodeObject,
       JsUndefined, JsNull, JsBoolean, JsNumber, JsString, JsBigInt, JsSymbol,
       JsObject, JsFunction, JsPromise
export value, node_value
export set!, instanceof
include("types/bases.jl")
include("types/node_value.jl")
include("types/common.jl")
include("types/primitives.jl")
include("types/objects.jl")
include("types/arrays.jl")
include("types/functions.jl")
include("types/external.jl")
include("types/promises.jl")


export global_env
include("env.jl")

end # module
