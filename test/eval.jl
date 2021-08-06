include("test_common.jl")
using IOCapture

@testset "eval" begin
    new_context()
    Math = node"Math"
    @test Math isa JsObject
    @test Math.random() isa Float64
    @test node"a = true"
    @test node"const b = 1" ≡ nothing
    @test node"let c = {}" ≡ nothing
    @test node"b" == 1
    captured = IOCapture.capture() do
        node"console".log("logging to stdout")
    end
    @test captured.output == "logging to stdout\n"
    delete_context()
end