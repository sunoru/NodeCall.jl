include("test_common.jl")
using Random

new_context()

@testset "errors" begin
    @test_throws NodeError node"x"
    p = node"(async () => { throw('async error') })()"
    @test_throws NodeError wait(p)
    err = try
        node"throw('error')"
    catch e
        e
    end
    @test startswith(sprint(show, err), "NodeError(")
    @test startswith(sprint(showerror, err), "NodeError:")
    @test_throws NodeError begin
        node_throw("error")
        NodeCall.throw_error()
    end
    @test_throws NodeError node"f=>f()"() do
        error("error")
    end
end

@testset "references" begin
    x = rand()
    NodeCall.reference(x)
    ref = NodeCall.reference(x)
    ref2 = NodeCall.reference(x)
    @test pointer(ref) == pointer(ref2)
    NodeCall.dereference(x)
    NodeCall.dereference(pointer(ref))
    @test NodeCall.delete_reference(pointer(ref2))
    @test !NodeCall.delete_reference(C_NULL)
end

@testset "internals" begin
    @test JsValue(2) == 2
    @test JsValue(Bool, node"true"o)
    @test value(value(NodeValueTemp, 1)) == 1
    struct S end
    o = node"{}"o
    @test_throws ErrorException convert(S, o)
    @test NodeCall.is_array(["a", "b"])
    @test NodeCall.get_type(123) == NodeCall.NapiTypes.napi_number
    o2 = node"1"o
    @test startswith(sprint(show, o), "NodeObject:")
    @test startswith(sprint(show, o2), "NodeValueTemp:")
    o = nothing
    o2 = nothing
    GC.gc()
    NodeCall.dispose()
end
