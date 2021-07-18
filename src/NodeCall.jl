module NodeCall

using libnode_jll
using libjlnode_jll

include("types/napi_types.jl")
using .NapiTypes

include("refs.jl")
include("utils.jl")

export run_node, @node_str, require
include("eval.jl")

export NapiValue, NodeValue, JsValue,
       NodeValueTemp, NodeObject, NodeExternal,
       JsUndefined, JsNull, JsBoolean, JsNumber, JsString, JsBigInt, JsSymbol,
       JsObject, JsFunction, JsPromise
export napi_value, node_value, value
export create_object
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

export node_env, node_uvloop, restart_node
include("env.jl")

export node_cmd, npm_cmd, npm, npx_cmd, npx
include("npm.jl")

end # module
