include("test_common.jl")

@testset "contexts" begin
    NodeCall.clear_context()
    ctx1 = current_context()
    ctx2 = new_context(be_current=false)
    node"const f_ctx1 = () => true"
    switch_context(ctx2)
    node"const f_ctx2 = () => 1"
    @test node"f_ctx2()" == 1
    @test_throws NodeError node"f_ctx1()"
    @test list_contexts() == [ctx1, ctx2]
    switch_context(1)
    @test node"f_ctx1()"
    delete_context(ctx1)
    @test_throws NodeError node"f_ctx1()"
    @test node"f_ctx2()" == 1
end
