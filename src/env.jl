using libjlnode_jll
import Random

mutable struct EnvironmentConfig
    env::NapiEnv
end

const _GLOBAL_ENV = EnvironmentConfig(C_NULL)
global_env() = _GLOBAL_ENV.env

function initialize!(env, addon_path)
    @debug "Initializing NodeJS..."
    _env = Ref{NapiEnv}()
    ret = @ccall :libjlnode.initialize(addon_path::Cstring, _env::Ptr{NapiEnv})::Cint
    @assert ret == 0
    env.env = _env[]
    _initialize_types()
    run("""
        globalThis.$(tempvar_name) = {}
        globalThis.assert = require('assert').strict
    """)
    Random.seed!(_GLOBAL_RNG)
    @debug "NodeJS initialized."
    env
end

function dispose(env)
    @debug "Disposing NodeJS..."
    ret = @ccall :libjlnode.dispose()::Cint
    @assert ret == 0
    @debug "NodeJS disposed."
end

function __init__()
    initialize!(_GLOBAL_ENV, jlnode_addon)
    finalizer(dispose, _GLOBAL_ENV)
end
