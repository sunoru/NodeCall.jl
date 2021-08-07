include("test_common.jl")
using Random
using IOCapture

@testset "miscs" begin
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
end
