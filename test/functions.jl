include("test_common.jl")

@testset "functions" begin
    new_context()

    f1 = node"(x) => x * 2"
    @test f1 isa JsFunction
    @test f1(1) == 2
    @test f1("1") == 2
    @test f1("x") ≡ NaN
    node"function f2(x, y) {
        return x + y
    }"
    f2 = node"f2"
    @test f2(1, 5) == 6
    @test f2("a", 5) == "a5"
    @test f2(node"[]", []) == ""

    js_call = node"(f, ...args) => f(...args)"
    @test js_call(true) do x
        x
    end

    @test js_call(sort, [3, 2, 1]) == [1, 2, 3]
    js_sort = node"(x) => x.sort()"
    @test js_sort([3, 2, 1]) == [1, 2, 3]

    js_iterator = node"(function *() {
        yield 1
        yield 2
        yield 3
    })()"
    @test js_iterator isa JsIterator
    for (x, y) in zip(js_iterator, [1,2,3])
        @test x == y
    end
    for (x, y) in zip(node"[1,2,3]"o, [1,2,3])
        @test x == y
    end

    # Allow to pass in `this` by declaring a keyword argument
    js_has_this = node"{x: 5}"
    js_has_this.f = function (y; this)
        (y + this.x, this)
    end
    result, this = js_has_this.f(3)
    @test result == 8
    @test this == js_has_this

    delete_context()
end
