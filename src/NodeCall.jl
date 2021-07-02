module NodeCall

# using CxxWrap
# using jlnode_jll

export JsUndefined, JsNull, JsBoolean, JsNumber, JsString, JsBigInt, JsSymbol, JsObject, JsFunction
include("types.jl")

export NodeEnvironment
include("env.jl")

function __init__()
    @initcxx
    _GLOBAL_ENV[] = new_env()
end

end # module
