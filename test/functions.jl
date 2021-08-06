include("test_common.jl")

@testset "functions" begin
    new_context()

    func1 = node"() => true"
    @test func1 isa JsFunction
    @test func1()
    js_call = node"(f, ...args) => f(...args)"
    @test js_call(true) do x
        x
    end

    # @test js_call(sort, [3, 2, 1]) == [1, 2, 3]

    js_iterator = node"(function *() {
        yield 1
        yield 2
        yield 3
    })()"
    @test js_iterator isa JsIterator
    for (x, y) in zip(js_iterator, [1,2,3])
        @test x == y
    end

    delete_context()
end
