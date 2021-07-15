using NodeCall, Test
using Dates: DateTime

@testset "NodeCall.jl" begin

    @testset "types" begin
        # Primitive values:
        # `undefined` and `null`: both nothing
        @test node"undefined" ≡ nothing
        @test node"null" ≡ nothing
        # `boolean`:
        @test node"false" || node"true"
        # `number`: always `Float64`
        @test node"0" ≡ 0.0 && node"Infinity" ≡ Inf && node"NaN" ≡ NaN
        # `string`
        @test node"'a string'" ≡ "a string"
        # `bigint`
        @test node"282278710948156123453635394322245338923n" == 282278710948156123453635394322245338923
        # `symbol`
        @test node"Symbol.for('sym')" ≡ :sym

        # Objects:
        # `object`
        @test typeof(node"{}") ≡ JsObject
        @test typeof(node"[]"o) ≡ NodeObject
        # `function`
        @test typeof(node"eval") ≡ JsFunction{Nothing}

        # `Date`:
        @test typeof(node"new Date()") ≡ DateTime
        # `Array`: try to convert
        @test typeof(node"[]") ≡ Vector{Any}
        @test typeof(node"[1]") ≡ Vector{Float64}
        @test typeof(node"[2, 't']") ≡ Vector{Any}
        @test typeof(node"[3, 123n]") ≡ Vector{Real}
        # Typed arrays:
        @test typeof(node"new Int8Array(1)") ≡ Vector{Int8}
        @test typeof(node"new Uint8Array(1)") ≡ Vector{UInt8}
        @test typeof(node"new Uint8ClampedArray(1)") ≡ Vector{UInt8}
        @test typeof(node"new Int16Array(1)") ≡ Vector{Int16}
        @test typeof(node"new Uint16Array(1)") ≡ Vector{UInt16}
        @test typeof(node"new Int32Array(1)") ≡ Vector{Int32}
        @test typeof(node"new Uint32Array(1)") ≡ Vector{UInt32}
        @test typeof(node"new Float32Array(1)") ≡ Vector{Float32}
        @test typeof(node"new Float64Array(1)") ≡ Vector{Float64}
        @test typeof(node"new BigInt64Array(1)") ≡ Vector{Int64}
        @test typeof(node"new BigUint64Array(1)") ≡ Vector{UInt64}
        # `Map`, `WeekMap`, `Set`, `WeakSet`
        @test typeof(node"new Map()") ≡ Dict{Any, Any}
        @test typeof(node"new WeakMap()") ≡ JsObject
        @test typeof(node"new Set()") ≡ Set{Any}
        @test typeof(node"new WeakSet()") ≡ JsObject
        # `ArrayBuffer`, `SharedArrayBuffer`, `DataView`
        @test typeof(node"new ArrayBuffer(1)") ≡ Vector{UInt8}
        @test typeof(node"new SharedArrayBuffer(1)") ≡ JsObject # Vector{UInt8}
        @test typeof(node"new DataView(new ArrayBuffer(1))") ≡ Vector{UInt8}
        @test instanceof(node_value(Vector{Float64}()), node"Float64Array")
        # `Promise`
        @test typeof(node"new Promise(()=>{})") ≡ JsPromise  # TODO: implement Promise
    end

    @testset "eval" begin
        Math = node"Math"
        @test typeof(Math) ≡ JsObject
        @test typeof(Math.random()) ≡ Float64
        @test node"const b = [1, 2]" ≡ nothing
        node"""
        b[1] = 3
        let c = {x: 7, y: 'y', 5: false}
        """
        @test node"b" == [1, 3]
        c = node"c"
        # `Dict` converted from `JsObject` always has string keys.
        @test Dict(c) == Dict("x" => 7, "y" => "y", "5" => false)
        @test c.x ≡ 7.0 && c.y ≡ "y"
        d = node"d = new Object()"
        d.b = node"b"o
        d.c = c
        @test node"d.b === b && d.c === c"
    end

    @testset "functions" begin
        f1 = node"(x) => x * 2"
        @test f1(1) ≈ 2
        @test f1("1") ≈ 2
        @test f1("x") ≡ NaN
        node"function f2(x, y) {
            return x + y
        }"
        f2 = node"f2"
        @test f2(1, 5) ≈ 6
        @test f2("a", 5) ≡ "a5"
        @test f2(node"[]", []) ≡ ""
        f3 = node"(function* f3() {
            yield 1
            yield 2
            yield 3
        })"
        vs = []
        for x in f3()
            push!(vs, x)
        end
        @test all(vs .≈ [1, 2, 3])
        js_sort! = node"(x) => x.sort()"
        a1 = rand(10)
        js_sort!(a1)
        @test issorted(a1)
        # Dictionary: only support String as key type.
        dict = Dict("1"=>2, "3"=>4, "x"=>5)
        dict2 = node"""(d) => {
            d[1] = 5
            d[3] = 6
            d.x = 7
            return d
        }"""(dict)
        @test dict == Dict("1"=>5, "3"=>6, "x"=>7)
        @test dict === dict2
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
    end

    @testset "import" begin
        # Not support
        # node"import path from 'path'"
        path = require("path")
        @test path == node"require('path')"
        @test path.resolve(".") == abspath(".")[1:end-1]
        node"const fs = require('fs')"
    end

    @testset "miscs" begin
        @test read(node_cmd("--version"), String) |> strip == "v14.17.3"
        @test read(npm_cmd("--version"), String) |> strip == "6.14.13"
        @test read(npx_cmd("--version"), String) |> strip == "6.14.13"
    end

    @testset "arrays" begin
        arr1 = rand(Float64, 10)
        arr2 = reinterpret(UInt8, arr1)
        @test node"""(a, b) => a instanceof Float64Array &&
            b instanceof Uint8Array &&
            a.buffer === b.buffer
        """(a, b)
    end
end
