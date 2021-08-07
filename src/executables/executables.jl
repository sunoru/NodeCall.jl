using libnode_jll: node as node_cmd_func, artifact_dir

const NPM_DIR = joinpath(artifact_dir, "lib", "node_modules", "npm")

function cmd_gen(args...)
    cmd = node_cmd_func()
    for arg in args
        cmd = `$cmd $arg`
    end
    cmd
end

macro node_cmd(args)
    :(let cmd = @cmd $args
        cmd_gen(cmd)
    end)
end

macro npm_cmd(args)
    :(let cmd = @cmd($args), jsfile = joinpath(NPM_DIR, "bin", "npm-cli.js")
        cmd_gen(jsfile, cmd)
    end)
end

macro npx_cmd(args)
    :(let cmd = @cmd($args), jsfile = joinpath(NPM_DIR, "bin", "npx-cli.js")
        cmd_gen(jsfile, cmd)
    end)
end

function npx(args...)
    cmd = npx``
    append!(cmd.exec, args)
    Base.run(cmd)
end
