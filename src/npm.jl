using libnode_jll: node_path, artifact_dir

const NPM_DIR = joinpath(artifact_dir, "lib", "node_modules", "npm")

node_cmd(args...) = `$node_path $(join(args, ' '))`

npm_cmd(args...) = let jsfile = joinpath(NPM_DIR, "bin", "npm-cli.js")
    `$node_path $jsfile $(join(args, ' '))`
end

npm(args...; wait=true) = run(npm_cmd(args...); wait=wait)

npx_cmd(args...) = let jsfile = joinpath(NPM_DIR, "bin", "npx-cli.js")
    `$node_path $jsfile $(join(args, ' '))`
end

npx(args...; wait=true) = run(npx_cmd(args...); wait=wait)
