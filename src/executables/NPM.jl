module NPM

using JSON
import NodeCall: @npm_cmd

const COMMANDS = let o = false
    commands = String[]
    for line in split(read(npm`help`, String), '\n')
        if o
            isempty(line) && break
            for cmd in split(line, ',')
                cmd = strip(cmd)
                isempty(cmd) && continue
                push!(commands, cmd)
            end
        elseif startswith(line, "where")
            o = true
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

installed_packages(is_global=false) = ls("--depth=0", "--json", is_global ? "--global" : "") do json
    data = JSON.parse(json)
    data["dependencies"]
end

is_installed_locally(pkg) = pkg in keys(installed_packages(false))
is_installed_globally(pkg) = pkg in keys(installed_packages(true))
is_installed(pkg) = is_installed_locally(pkg) || is_installed_globally(pkg)

end
