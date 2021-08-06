include("test_common.jl")
using Random

@testset "errors" begin
    @test_throws NodeError node"throw('error')"
    p = node"(async () => { throw('async error') })()"
    @test_throws String wait(p)
end

@testset "internals" begin
    x = rand()
    NodeCall.reference(x)
    ref = NodeCall.reference(x)
    ref2 = NodeCall.reference(x)
    @test pointer(ref) == pointer(ref2)
    NodeCall.dereference(x)
    NodeCall.dereference(pointer(ref))
    @test NodeCall.delete_reference(pointer(ref2))
end
