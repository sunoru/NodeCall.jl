include("test_common.jl")
using Random

@testset "external" begin
    new_context()

    x = Ref(123)
    o = @new node"Object"()
    o.x = NodeExternal(x)
    @test o.x ≡ x

    delete_context()
end