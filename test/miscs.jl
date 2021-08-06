include("test_common.jl")
using Random

@testset "miscs" begin
    @test read(node("--version"), String) |> strip == "v14.17.3"
    @test read(npm("--version"), String) |> strip == "6.14.13"
    @test read(npx("--version"), String) |> strip == "6.14.13"
end
