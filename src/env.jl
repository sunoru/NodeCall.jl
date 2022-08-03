import Base: eventloop
import Libdl

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
const _STARTED_FROM_NODE = Ref(false)
started_from_node() = _STARTED_FROM_NODE[]

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

function initialize(args=split(get(ENV, "JLNODE_ARGS", "")), env=nothing)
    initialized() && return
    Libdl.dlopen(libnode, Libdl.RTLD_GLOBAL)
    _STARTED_FROM_NODE[] = !isnothing(env)
    env = if started_from_node()
        reinterpret(NapiEnv, UInt64(env))
    else
        start_node(args)
    end
    _GLOBAL_ENV.env = env
    _GLOBAL_ENV.loop = @napi_call env napi_get_uv_event_loop()::Ptr{Cvoid}
    ret = @ccall :libjlnode.initialize(
        _GLOBAL_ENV.loop::Ptr{Cvoid},
        pointer_from_objref(NodeCall)::Ptr{Cvoid}
    )::Cint
    @assert ret == 0
    @debug "Initializing NodeJS..."
    node_eval("""(() => {
        globalThis.$(TEMPVAR_NAME) = {}
        globalThis.assert = require('assert').strict
    })()""", RESULT_RAW, context=nothing)
    _initialize_globals()
    new_context()
    _INITIALIZED[] = true
    # run_node_uvloop()
    @debug "NodeJS initialized."
end

function dispose()
    !initialized() && return
    @debug "Disposing NodeJS..."
    _INITIALIZED[] = false
    ret = @ccall :libjlnode.dispose()::Cint
    @assert ret == 0
    @debug "NodeJS disposed."
end

function start_node(args=split(get(ENV, "JLNODE_ARGS", "")))
    initialized() && return
    @debug "Starting NodeJS instance..."
    env = Ref{NapiEnv}()
    ret = @ccall :libjlnode.start_node(
        jlnode_addon::Cstring,
        args::Ptr{Cstring},
        length(args)::Csize_t,
        env::Ptr{NapiEnv}
    )::Cint
    @assert ret == 0
    env[]
end

function __init__()
    # Auto start and initialize NodeJS if in REPL.
    if isinteractive()
        initialize()
    end
    finalizer(_GLOBAL_ENV) do _
        dispose()
    end
end
