include("test_common.jl")
using Suppressor

@testset "eval" begin
    new_context()

    @test node"1 == 1"
    @test value(node"123"o) == 123
    Math = node"Math"
    @test Math isa JsObject
    @test Math.random() isa Float64
    @test node"a = true"
    @test node"const b = 1"r isa NapiValue
    @test node"let c = {}"g ≡ nothing
    @test node"b" == 1
    @test "logging to stdout\n" == @capture_out node"console".log("logging to stdout")
    x = 5
    @test node"const x = $x" ≡ nothing
    @test node"const \$ = 1" ≡ nothing
    @test node"\$" == 1
    x = 2x
    @test node"$(x)" == 10
    @test node"'$x'" == raw"$x"
    @test node"`$x`" == raw"$x"
    @test node"`${x}`" == "5"
    @test node"`${$x}`" == "10"
    y = "x"
    @test node"$y" == "x"
    @test node"$$y" == 5
    @test_throws NodeError node"() => $x"()
    @test node"() => $x"k() == 10

    delete_context()
end