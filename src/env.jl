import Base: eventloop
import Random

using libjlnode_jll

mutable struct EnvironmentConfig
    env::NapiEnv
    loop::Ptr{Cvoid}
    context_index::Int
end

const _GLOBAL_ENV = EnvironmentConfig(C_NULL, C_NULL, 0)
node_env() = _GLOBAL_ENV.env
node_uvloop() = _GLOBAL_ENV.loop
const _INITIALIZED = Ref(false)
initialized() = _INITIALIZED[]

@enum UvRunMode begin
  UV_RUN_DEFAULT = 0
  UV_RUN_ONCE
  UV_RUN_NOWAIT
end
# It has to been called manually for now.
# HELP WANTED: https://github.com/sunoru/NodeCall.jl/issues/1
function run_node_uvloop(mode::UvRunMode=UV_RUN_DEFAULT)
    node_loop = node_uvloop()
    @ccall :libjlnode.node_uv_run(node_loop::Ptr{Cvoid}, mode::UvRunMode)::Cint
    # @async begin
    #     node_loop = node_uvloop()
    #     while initialized()
    #         yield()
    #         # UV_RUN_NOWAIT
    #         @ccall :libjlnode.uv_run(node_loop::Ptr{Cvoid}, 2::Cint)::Cint
    #     end
    # end
end

function initialize!(env, addon_path, args)
    @debug "Initializing NodeJS..."
    _env = Ref{NapiEnv}()
    loop = Ref{Ptr{Cvoid}}()
    ret = @ccall :libjlnode.initialize(
        pointer_from_objref(NodeCall)::Ptr{Cvoid},
        addon_path::Cstring,
        args::Ptr{Cstring},
        length(args)::Csize_t,
        _env::Ptr{NapiEnv},
        loop::Ptr{Ptr{Cvoid}}
    )::Cint
    @assert ret == 0
    env.env = _env[]
    env.loop = loop[]
    run_script("""(() => {
        globalThis.$(tempvar_name) = {}
        globalThis.assert = require('assert').strict
    })()""", raw=true, context=nothing)
    _initialize_types()
    new_context()
    Random.seed!(_GLOBAL_RNG)
    _INITIALIZED[] = true
    # run_node_uvloop()
    @debug "NodeJS initialized."
    env
end

function dispose!(_env)
    if !initialized()
        return
    end
    @debug "Disposing NodeJS..."
    _INITIALIZED[] = false
    ret = @ccall :libjlnode.dispose()::Cint
    @assert ret == 0
    @debug "NodeJS disposed."
end

function start_node(args=split(get(ENV, "JLNODE_ARGS", "")))
    initialize!(_GLOBAL_ENV, jlnode_addon, args)
end

function __init__()
    if get(ENV, "JLNODE_AUTOSTART", "1") == "1"
        start_node()
    end
    finalizer(dispose!, _GLOBAL_ENV)
end
