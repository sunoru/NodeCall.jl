include("test_common.jl")

@testset "threading" begin
    new_context()

    unsafe_f = node"x => x * 2"
    tsf = @threadsafe unsafe_f::Int
    t = @async tsf(1)
    # Must use `@await` instead of `fetch` since we use node functions in the `Task`.
    @test 2 ≡ @await t
    @test_throws TaskFailedException (@await @async tsf("a"))

    function unsafe_f2(x)
        o = node"{}"
        @threadsafe o.x = x
        o
    end
    @test 0.1 == unsafe_f2(0.1).x
    p = @async @threadsafe unsafe_f2("Hello")
    @test (@await p).x == "Hello"

    delete_context()
end