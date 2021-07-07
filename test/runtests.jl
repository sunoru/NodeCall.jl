using NodeCall, Test

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
        @test node"28227453635394322245338923n" ≡ 28227453635394322245338923
        # `symbol`
        @test node"Symbol.for('sym')" ≡ :sym

        # Objects:
        # `object`
        @test typeof(node"{}") ≡ JsObject
        @test typeof(node"[]"o) ≡ NodeObject
        # `function`
        @test typeof(node"eval") ≡ JsFunction

        # `Date`:
        @test typeof(node"new Date()") ≡ Date
        # `Array`: try to convert
        @test typeof(node"[]") ≡ Vector{Any}
        @test typeof(node"[1]") ≡ Vector{Float64}
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
        @test typeof(node"new WeakMap()") ≡ Dict{Any, Any}
        @test typeof(node"new Set()") ≡ Set{Any}
        @test typeof(node"new WeakSet()") ≡ Set{Any}
        # `ArrayBuffer`, `SharedArrayBuffer`, `DataView`
        @test typeof(node"new ArrayBuffer(1)") ≡ Vector{UInt8}
        @test typeof(node"new SharedArrayBuffer(1)") ≡ Vector{UInt8}
        @test typeof(node"new DataView(new ArrayBuffer(1))") ≡ Vector{UInt8}
        # `Promise`
        @test typeof(node"new Promise()") ≡ Task
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
        @test Array(node"b") == [1, 3]
        c = node"c"
        # `Dict` converted from `JsObject` always has string keys.
        @test Dict(c) == Dict("x" => 7, "y" => "y", "5" => false)
        @test c.x ≡ 7.0 && c.y ≡ "y"
        d = node"new Object()"
        d.b = node"b"
        d.c = c
        @test node"d.b === b && d.c === c"
    end

    @testset "functions" begin
        f1 = node"(x) => x * 2"
        @test f1(1) ≈ 2
        @test f1("1") ≈ 2
        @test f1("x") ≡ NaN
        f2 = node"function f2(x, y) {
            return x + y
        }"
        @test f2(1, 5) ≈ 6
        @test f2("a", 5) ≡ "a5"
        @test f2(node"[]", []) ≡ ""
        f3 = node"function* generator() {
            yield 1;
            yield 2;
            yield 3;
        }"
        @test collect(f3) .≈ [1, 2, 3]
    end

    @testset "import" begin
        node"import path from 'path'"
        path = require("path")
        @test path ≡ node"path"
        @test path.resolve(".") ≡ abspath(".")
        node"const fs = require('fs')"
        @test Array(node"fs".opendir(".")) == Array(node"fs.opendir('.')")
    end
end
