module NodeCall

using libnode_jll
using libjlnode_jll

include("types/napi_types.jl")
using .NapiTypes

include("refs.jl")
include("utils.jl")

export run_script, @node_str, require
include("eval.jl")

export NapiValue, NodeValue, JsValue, NodeError,
       NodeValueTemp, NodeObject, NodeExternal,
       JsUndefined, JsNull, JsBoolean, JsNumber, JsString, JsBigInt, JsSymbol,
       JsObject, JsFunction, JsPromise
export napi_value, node_value, value
export create_object
export set!, instanceof
export @await, state, result
export node_throw
include("types/bases.jl")
include("types/node_value.jl")
include("types/errors.jl")
include("types/common.jl")
include("types/primitives.jl")
include("types/objects.jl")
include("types/arrays.jl")
include("types/functions.jl")
include("types/external.jl")
include("types/promises.jl")

export current_context, new_context, delete_context, switch_context, list_contexts
include("contexts.jl")

export node_env, node_uvloop, run_node_uvloop
include("env.jl")

export node, npm, npx
include("executables.jl")

end # module
