include("test_common.jl")
using Random

@testset "external" begin
    new_context()

    x = Ref(123)
    o = @new node"Object"()
    o.x = NodeExternal(x)
    @test o.x ≡ x
    ox = get(o, "x", result=RESULT_NODE)
    @test sprint(show, ox) == "NodeExternal: Base.RefValue{Int64}(123)"
    @test node_value(ox) ≡ ox

    ptr = backtrace()[1]
    ptr_int = Ptr{Int}(ptr)
    @test ptr ≡ value(napi_value(ptr))
    @test ptr_int ≡ value(napi_value(ptr_int))

    delete_context()
end