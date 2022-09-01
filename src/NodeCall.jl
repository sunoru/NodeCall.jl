module NodeCall

using libnode_jll
using libjlnode_jll

export NapiTypes
include("napi_types.jl")
using .NapiTypes

include("refs.jl")
include("utils.jl")
include("types/bases.jl")
include("types/node_values.jl")

export RESULT_RAW, RESULT_NODE, RESULT_VALUE
export node_eval
include("eval.jl")

export require, node_import, ensure_dynamic_import
export @node_str, @node_import
include("import.jl")

export NapiValue, NodeValue, JsValue, NodeError,
       NodeValueTemp, NodeObject, NodeExternal,
       JsUndefined, JsNull, JsBoolean, JsNumber, JsString, JsBigInt, JsSymbol,
       JsObject, JsIterator, JsFunction, JsPromise
export napi_value, node_value, value
export create_object, @new
export set_copy_array
export set!, instanceof
export this
export @node_async, state, result
export node_throw
include("types/errors.jl")
include("types/common.jl")
include("types/primitives.jl")
include("types/objects.jl")
include("types/arrays.jl")
include("types/functions.jl")
include("types/externals.jl")
include("types/promises.jl")
include("types/jlnode_helpers.jl")

export current_context, new_context, delete_context, switch_context, list_contexts
include("contexts.jl")

export node_env, node_uvloop, run_node_uvloop
include("env.jl")

export threadsafe_call, @threadsafe, @await
include("threading.jl")

export @node_cmd, @npm_cmd, @npx_cmd
export NPM, npx
include("executables/executables.jl")
include("executables/NPM.jl")

end # module
