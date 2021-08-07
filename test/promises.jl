include("test_common.jl")
using Dates

@testset "promises" begin
    js_sleep = node"""(ms) => new Promise(
        resolve => setTimeout(() => resolve(ms), ms)
    )"""
    t = now()
    p = js_sleep(500)
    @test fetch(p) == 500
    @test now() - t ≥ Millisecond(500)
    @test state(napi_value(p)) == NodeCall.promise_fulfilled
    @test result(p) == 500
    async_f = node"""async (x) => {
        return x * 2
    }"""
    y = 0
    p2 = async_f(50).then() do x
        y = x
        x * 2
    end
    @test 200 == @await p2
    @test y == 100

    p3 = JsPromise() do resolve, _
        resolve(true)
    end
    @test @await p3
    p4 = JsPromise() do _, reject
        reject(123)
    end
    @test_throws NodeError wait(p4)
end