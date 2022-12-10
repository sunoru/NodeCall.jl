module NPM

using JSON
using NodeCall: @npm_cmd

const COMMANDS = let o = 0
    commands = String[]
    for line in split(read(npm`help`, String), '\n')
        if o ≡ 2
            isempty(line) && break
            for cmd in split(line, ',')
                cmd = strip(cmd)
                isempty(cmd) && continue
                push!(commands, cmd)
            end
        elseif startswith(line, "All commands")
            o = 1
        elseif o ≡ 1
            o = 2
        end
    end
    Tuple(commands)
end

for cmd in COMMANDS
    cmd_sym = Symbol(replace(cmd, '-'=>'_'))
    @eval function $cmd_sym(args...; wait=true)
        cmd = @npm_cmd($cmd)
        append!(cmd.exec, filter(!isempty, args))
        if wait
            Base.run(cmd)
        else
            Base.open(cmd)
        end
    end
    @eval function $cmd_sym(f::Function, args...)
        p = $cmd_sym(args...; wait=false)
        ret = f(p)
        close(p)
        ret
    end
end

installed_packages(is_global=false) = NPM.ls("--depth=0", "--json", is_global ? "--location=global" : "") do json
    data = JSON.parse(json)
    Base.get(data, "dependencies", Dict{String, Any}())
end

is_installed(pkg; is_global=nothing) = if isnothing(is_global)
    is_installed(pkg; is_global=false) || is_installed(pkg; is_global=true)
else
    pkg in keys(installed_packages(is_global))
end

end
