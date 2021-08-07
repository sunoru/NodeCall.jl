module NPM

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
    @eval function $cmd_sym(args...)
        cmd = @npm_cmd($cmd)
        append!(cmd.exec, args)
        Base.run(cmd)
    end
end

end
