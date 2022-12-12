import Base: eventloop
import Libdl

using libjlnode_jll

const _NODE_ENV = Ref{NapiEnv}()
const _NODE_UVLOOP = Ref(C_NULL)
const _INITIALIZED = Ref(false)
const _STARTED_FROM_NODE = Ref(false)
const _GLOBAL_TASK = Ref{Task}()

node_env() = _NODE_ENV[]
node_uvloop() = _NODE_UVLOOP[]
initialized() = _INITIALIZED[]
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
    @ccall libjlnode.node_uv_run(node_loop::Ptr{Cvoid}, mode::UvRunMode)::Cint
end

"""
    initialize(env=nothing; node_args=[])

Must be called in the main thread.
"""
function initialize(env=nothing; node_args=String[])
    initialized() && return
    _GLOBAL_TASK[] = current_task()
    Libdl.dlopen(libnode, Libdl.RTLD_GLOBAL | Libdl.RTLD_LAZY | Libdl.RTLD_DEEPBIND)
    _STARTED_FROM_NODE[] = !isnothing(env)
    env = if started_from_node()
        reinterpret(NapiEnv, UInt64(env))
    else
        start_node(node_args)
    end
    _NODE_ENV[] = env
    _NODE_UVLOOP[] = @napi_call env napi_get_uv_event_loop()::Ptr{Cvoid}
    ret = @ccall libjlnode.initialize(
        _NODE_UVLOOP[]::Ptr{Cvoid},
        _jlnode_util_functions()::_JlnodeUtilFunctions
    )::Cint
    @assert ret == 0
    @debug "Initializing NodeJS..."
    node_eval("""(() => {
        globalThis.$(TEMPVAR_NAME) = {}
        globalThis.assert = require('assert').strict
    })()""", RESULT_RAW, context=nothing)
    ensure_dynamic_import()
    initialize_node_consts()
    new_context()
    _INITIALIZED[] = true
    # run_node_uvloop()
    @debug "NodeJS initialized."
end

function dispose()
    !initialized() && return
    @debug "Disposing NodeJS..."
    _INITIALIZED[] = false
    ret = @ccall libjlnode.dispose()::Cint
    @assert ret == 0
    @debug "NodeJS disposed."
end

function start_node(args=String[])
    initialized() && return
    @debug "Starting NodeJS instance..."
    env = Ref{NapiEnv}()
    ret = @ccall libjlnode.start_node(
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
    if isinteractive() && get(ENV, "JLNODE_DISABLE_AUTO_START", "0") == "0"
        initialize()
    end
    atexit(dispose)
end
