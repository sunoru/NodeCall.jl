include("test_common.jl")
using Random
using Suppressor

@testset "executables" begin
    @test read(node`--version`, String) |> strip == "v14.17.3"
    @test read(npm`--version`, String) |> strip == "6.14.13"
    @test @capture_out(begin
        npx("--version")
    end)|> strip == "6.14.13"
    ps = [
        getproperty(NPM, Symbol(replace(command, '-'=>'_')))("--help"; wait=false)
        for command in NPM.COMMANDS
    ]
    wait.(ps)
    @suppress NPM.init("-y")
    @suppress NPM.install("canvas") do p
        wait(p)
    end
    @test NPM.is_installed("canvas")
    @test NPM.is_installed("canvas"; is_global=true) isa Bool
end
