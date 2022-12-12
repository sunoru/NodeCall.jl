using Test, NodeCall
using Suppressor

@testset "executables" begin
    @test success(node`--version`)
    @test read(npm`--version`, String) == read(npx`--version`, String)
    ps = [
        getproperty(NPM, Symbol(replace(command, '-'=>'_')))("--help"; wait=false)
        for command in NPM.COMMANDS
    ]
    wait.(ps)
    @suppress npx("--version")
    @suppress NPM.init("-y")
    @suppress NPM.install("bcrypt") do p
        wait(p)
    end
    @test NPM.is_installed("bcrypt")
    @test NPM.is_installed("bcrypt"; is_global=true) isa Bool
end
