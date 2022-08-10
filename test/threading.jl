include("test_common.jl")

@testset "threading" begin
    new_context()

    unsafe_f = node"x => x * 2"
    tsf = @threadsafe unsafe_f::Int
    t = @async tsf(1)
    # Must use `@await` instead of `fetch` since we use node functions in the `Task`.
    @test 2 ≡ @await t
    @test_throws TaskFailedException @await @async tsf("a")

    function tsf2(x)
        o = @threadsafe node"{}"
        @threadsafe o.x = x
        o
    end
    o = @await @async tsf2(5)
    @test o.x == 5

    delete_context()
end