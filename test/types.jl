include("test_common.jl")
using Dates

macro check_type(js_script, jl_type, jl_script=nothing, js_type=nothing)
    quote
        @test $js_script isa $jl_type
        if !isnothing($js_type)
            @test instanceof($jl_script, $js_type)
        end
    end
end

@testset "types" begin
    # Primitive values:
    # `undefined` and `null`: both nothing
    @test node"undefined" ≡ nothing
    @test node"null" ≡ nothing
    # `boolean`:
    @test node"false" || node"true"
    @test node"x => typeof x === 'boolean'"(false)
    # `number`: always `Float64`
    @test node"0" ≡ 0.0 && node"Infinity" ≡ Inf && node"NaN" ≡ NaN
    @test node"x => typeof x === 'number'"(0)
    # `string`
    @test node"'a string'" ≡ "a string"
    @test node"x => typeof x === 'string'"("str")
    # `bigint`
    @test node"282278710948156123453635394322245338923n" == 282278710948156123453635394322245338923
    @test node"x => typeof x === 'bigint'"(BigInt(0))
    # `symbol`
    @test node"Symbol.for('sym')" ≡ :sym
    @test node"x => typeof x === 'symbol'"(:sym)

    # Objects:
    # `object`
    @test node"[]"o isa NodeObject
    @check_type node"{}" JsObject (x=1,) node"Object" 
    # `function`
    @check_type node"eval" JsFunction{Nothing} println node"Function"

    # `Date`:
    @check_type node"new Date()" DateTime now() node"Date"
    # `Array`: try to convert
    @check_type node"[]"        Vector{Any} [] node"Array"
    @check_type node"[1]"       Vector{Float64}
    @check_type node"[2, 't']"  Vector{Any}
    @check_type node"[3, 123n]" Vector{Real}
    # Typed arrays:
    @check_type node"new Int8Array(1)"         Vector{Int8}     Int8[]    node"Int8Array"
    @check_type node"new Uint8Array(1)"        Vector{UInt8}    UInt8[]   node"Uint8Array"
    @check_type node"new Uint8ClampedArray(1)" Vector{UInt8}
    @check_type node"new Int16Array(1)"        Vector{Int16}    Int16[]   node"Int16Array"    
    @check_type node"new Uint16Array(1)"       Vector{UInt16}   UInt16[]  node"Uint16Array"   
    @check_type node"new Int32Array(1)"        Vector{Int32}    Int32[]   node"Int32Array"    
    @check_type node"new Uint32Array(1)"       Vector{UInt32}   UInt32[]  node"Uint32Array"   
    @check_type node"new Float32Array(1)"      Vector{Float32}  Float32[] node"Float32Array"  
    @check_type node"new Float64Array(1)"      Vector{Float64}  Float64[] node"Float64Array"  
    @check_type node"new BigInt64Array(1)"     Vector{Int64}    Int64[]   node"BigInt64Array" 
    @check_type node"new BigUint64Array(1)"    Vector{UInt64}   UInt64[]  node"BigUint64Array"
    # `Map`, `WeekMap`, `Set`, `WeakSet`
    @check_type node"new Map()"     Dict{Any, Any}
    @check_type node"new WeakMap()" JsObject
    @check_type node"new Set()"     Set{Any}
    @check_type node"new WeakSet()" JsObject
    # `ArrayBuffer`, `SharedArrayBuffer`, `DataView`
    @check_type node"new ArrayBuffer(1)" Vector{UInt8}
    @check_type node"new SharedArrayBuffer(1)" JsObject # Vector{UInt8}
    @check_type node"new DataView(new ArrayBuffer(1))" Vector{UInt8}
    # `Promise`
    @check_type node"new Promise(()=>{})" JsPromise

    o = node"{}"o
    @test value(Rational{Int}, node"0.75"o) == 3//4
    @test value(String, o) == "[object Object]"
    @test value(Int, node"123"o) == 123
    @test value(Int, node"123n"r, is_bigint=true) == 123
    @test value(UInt, node"123n"o) == UInt(123)
end
