function run(
    env::NodeEnvironment,
    script::AbstractString;
    convert_result = true
)
    # TODO
end

run(script; kwargs...) = run(global_env(), script; kwargs...)

macro node_str(code, options...)
    # TODO
end

require(env::NodeEnvironment, id::AbstractString) = run(env, "globalThis.require($(id))")
