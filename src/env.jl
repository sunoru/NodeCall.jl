using Pkg.Artifacts

const node_exe_name = Sys.iswindows() ? "node.exe" : "node"
const npm_exe_name = Sys.iswindows() ? "npm.cmd" : "npm"

node_path() = get(ENV, "NODECALL_NODE_PATH", node_exe_name)

mutable struct NodeEnvironment
    process::Base.Process
    env::Ptr{Nothing}
end

function new_env()
    cmd = `$(node_path()) $bootstrap_script_path`
    process = open(cmd)
    env = Ptr{Nothing}(read(process, UInt64))
    NodeEnvironment(process, env)
end

const _GLOBAL_ENV = Ref{NodeEnvironment}()
global_env() = _GLOBAL_ENV[]
