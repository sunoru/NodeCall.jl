include("test_common.jl")
using Dates
using JSON

module FooModule
using NodeCall
export SOME_CONST
NodeCall.@global_node_const SOME_CONST = "{x: 1}"
__init__() = NodeCall.initialize_node_consts()
end

@testset "objects" begin
    new_context()

    Object = node"Object"
    node"const a = new Object()"
    a = node"a"
    b = @new Object
    b.a = node"a"
    @test b.a == node"a"
    @test node"(b) => b.a === a"(b)
    @test hasproperty(b, :a)
    b[1] = 123
    @test b[1] == 123
    @test JSON.json(b) == "{\"1\":123.0,\"a\":{}}"
    delete!(b, 1)
    delete!(b, "a")
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

    @test node"new Date('2007-01-28')" == DateTime(2007, 1, 28)

    str_dict = Dict("k"=>false, "p"=>123)
    str_dict_nv = node_value(str_dict)
    @test Dict(str_dict_nv) == str_dict
    @test value(Dict{String, Int}, str_dict_nv) == str_dict
    @test "k" ∈ str_dict_nv
    @test Object.keys(str_dict) == ["k", "p"]
    # `Dict` is mutable.
    mutated_dict = node"""(dict) => {
        dict.p += 1
        dict.a = 456
        return dict
    }"""(str_dict_nv)
    @test str_dict["p"] == 124
    @test str_dict["a"] == 456
    @test mutated_dict ≡ str_dict

    int_dict = Dict(false=>false, 123=>456)
    @test Object.keys(int_dict) == ["false", "123"]
    @test node"(d) => d[0]"(int_dict) ≡ false
    int_dict2 = Dict(1=>2, 3=>4)
    @test node"(d) => d[1]"(int_dict2) ≡ 2.0

    js_map = node"""(() => {
        const m = new Map()
        m.set(1, 2)
        m.set("x", 3)
        return m
    })()"""
    @test value(js_map) == Dict(1=>2, "x"=>3)

    some_set = Set([1, 2])
    some_set_nv = node_value(some_set)
    @test Set(some_set_nv) == some_set
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
    @test value(NamedTuple{(:x, :y), Tuple{String, Bool}}, named_tuple3) ≡ (x="t", y=true)

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
    @test Object.keys(foo_m) == ["x"]

    @test length(node"{length: 5}") == 5

    @test FooModule.SOME_CONST.x == 1
    @test Object.keys(FooModule) == ["FooModule", "SOME_CONST"]

    delete_context()
end
