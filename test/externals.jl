include("test_common.jl")
using Random

@testset "external" begin
    new_context()

    x = Ref(123)
    o = @new node"Object"()
    o.x = NodeExternal(x)
    @test o.x ≡ x
    ox = get(o, "x", convert_result=false)
    @test sprint(show, ox) == "NodeExternal: Base.RefValue{Int64}(123)"
    @test node_value(ox) ≡ ox

    delete_context()
end