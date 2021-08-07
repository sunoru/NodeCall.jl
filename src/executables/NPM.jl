module NPM

import NodeCall: @npm_cmd

let help_str = read(npm`help`, String)
end

end
