include("test_common.jl")
using Random
using IOCapture

@testset "executables" begin
    @test read(node`--version`, String) |> strip == "v14.17.3"
    @test read(npm`--version`, String) |> strip == "6.14.13"
    @test IOCapture.capture() do
        npx("--version")
    end.output |> strip == "6.14.13"
    IOCapture.capture() do
        for command in NPM.COMMANDS
            getproperty(NPM, Symbol(replace(command, '-'=>'_')))("--help")
        end
    end
    close(NPM.init("-y"; wait=false))
    NPM.install("canvas") do _
    end
    @test NPM.is_installed("canvas")
    @test NPM.is_installed_globally("canvas") isa Bool
end
