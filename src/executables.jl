using libnode_jll: node as node_cmd, artifact_dir

const NPM_DIR = joinpath(artifact_dir, "lib", "node_modules", "npm")

node(args...) = let cmd = node_cmd()
    `$cmd $args`
end

npm(args...) = let cmd = node_cmd(), jsfile = joinpath(NPM_DIR, "bin", "npm-cli.js")
    `$cmd $jsfile $args`
end

npx(args...) = let cmd = node_cmd(), jsfile = joinpath(NPM_DIR, "bin", "npx-cli.js")
    `$cmd $jsfile $args`
end
