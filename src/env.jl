using libjlnode_jll
import Random

mutable struct EnvironmentConfig
    env::NapiEnv
end

const _GLOBAL_ENV = EnvironmentConfig(C_NULL)
global_env() = _GLOBAL_ENV.env
const _INITIALIZED = Ref(false)
initialized() = _INITIALIZED[]

function initialize!(env, addon_path)
    @debug "Initializing NodeJS..."
    _env = Ref{NapiEnv}()
    ret = @ccall :libjlnode.initialize(
        pointer_from_objref(NodeCall)::Ptr{Cvoid},
        addon_path::Cstring,
        _env::Ptr{NapiEnv}
    )::Cint
    @assert ret == 0
    env.env = _env[]
    run_node("""(() => {
        globalThis.$(tempvar_name) = {}
        globalThis.assert = require('assert').strict
    })()""")
    _initialize_types()
    Random.seed!(_GLOBAL_RNG)
    _INITIALIZED[] = true
    @debug "NodeJS initialized."
    env
end

function dispose(env)
    @debug "Disposing NodeJS..."
    _INITIALIZED[] = false
    ret = @ccall :libjlnode.dispose()::Cint
    @assert ret == 0
    @debug "NodeJS disposed."
end

function __init__()
    initialize!(_GLOBAL_ENV, jlnode_addon)
    finalizer(dispose, _GLOBAL_ENV)
end
