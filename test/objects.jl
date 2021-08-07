include("test_common.jl")
using Dates

@testset "objects" begin
    new_context()

    Object = node"Object"
    node"const a = new Object()"
    a = node"a"
    b = @new Object
    b.a = node"a"
    @test b.a == node"a"
    @test node"(b) => b.a === a"(b)
    b[a] = true
    @test hasproperty(b, :a)
    @test a ∈ b
    @test b[a]
    b[1] = 123
    @test b[1] == 123
    delete!(b, 1)
    delete!(b, "a")
    delete!(b, a)
    @test all((!haskey).([b], ["a", a, 1]))

    node"""class A {
        constructor(a, b) {
            this.c = a * b
        }
    }"""
    ClassA = node"A"
    instance = @new ClassA(4, 5)
    @test instance.c == 20
    @test instanceof(instance, ClassA)
    @test !instanceof(instance, nothing)

    @test node"new Date('2007-01-28')" == DateTime(2007, 1, 28)

    str_dict = Dict("k"=>false, "p"=>123)
    any_dict = Dict(false=>false, 123=>456)
    @test "k" ∈ node_value(str_dict)
    @test Object.keys(str_dict) == ["k", "p"]
    @test Object.keys(any_dict) == ["false", "123"]
    js_map = node"""(() => {
        const m = new Map()
        m.set(1, 2)
        m.set("x", 3)
        return m
    })()"""
    @test value(js_map) == Dict(1=>2, "x"=>3)

    some_set = Set([1, 2])
    mutated_set = node"""(set) => {
        set.add(3)
        return set
    }"""(some_set)
    @test mutated_set == Set([1, 2, 3])
    # `Set` is not mutable.
    @test some_set ≠ mutated_set

    tuple = ("a", "b")
    tuple2 = node"""(tuple) => {
        tuple[0] = "c"
        return tuple
    }"""(tuple)
    @test tuple2 == ("c", "b")
    tuple3 = node"""(tuple) => {
        tuple.push(123)
        return tuple
    }"""(tuple)
    @test tuple3 == ["a", "b", 123]

    named_tuple = (x=1, y=true, z="z")
    @test Object.keys(named_tuple) == ["x", "y", "z"]
    named_tuple2 = node"""(nt) => {
        assert(nt.x === 1 && nt.y && nt.z === 'z')
        nt.x = 5
        return nt
    }"""(named_tuple)
    @test named_tuple2 ≡ (x=5, y=true, z="z")
    named_tuple3 = node"""(nt) => {
        nt.x = 't'
        return nt
    }"""(named_tuple)
    @test named_tuple3 isa JsObject
    @test "x" in named_tuple3
    @test NamedTuple(named_tuple3) ≡ (x="t", y=true, z="z")

    struct Foo
        x::Int
    end
    @test node"(foo) => (foo.x = 3, foo)"(Foo(5)) == Foo(3)
    mutable struct FooM
        x::String
    end
    foo_m = FooM("before")
    node"(foo, s) => (foo.x = s, foo)"(foo_m, "after")
    @test foo_m.x == "after"
    @test node"(foo) => 'x' in foo && foo.x === 'after'"(foo_m)

    @test length(node"{length: 5}") == 5

    delete_context()
end
