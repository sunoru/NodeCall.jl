include("test_common.jl")
using Random

@testset "arrays" begin
    new_context()

    arr1 = collect(1.0:20.0)
    arr2 = reinterpret(Float32, arr1)
    bytes = reinterpret(UInt8, arr2)
    # JavaScript's arrays start with 0.
    buffer = node"(arr1, arr2) => {
        arr1[0] = 5
        arr2[3] = 4
        return arr1.buffer
    }"(arr1, arr2)
    @test buffer == bytes
    @test pointer(buffer) == pointer(arr2)
    @test arr1[1:2] == [5, 512]
    set_copy_array(true)
    js_arr = node_value(arr1)
    @test length(js_arr) == 20
    # `in` is checking indices.
    @test 0 in js_arr
    @test js_arr[0] == 5
    arr3 = Array(js_arr)
    set_copy_array(false)
    @test pointer(arr1) != pointer(arr3)
    js_arraybuffer = get(js_arr, "buffer", result=RESULT_NODE)
    @test length(js_arraybuffer) == 160
    dataview = @new node"DataView"(js_arraybuffer)
    @test length(dataview) == 160

    js_buffer = node"Buffer.alloc(5)"o
    @test value(Vector{UInt8}, js_buffer) == zeros(UInt8, 5)
    @test length(js_buffer) == 5
    @test Tuple(js_buffer) == Tuple(zeros(UInt8, 5))
    @test value(Tuple{Int, Int}, node"[1,2]"o) == (1, 2)

    # Bug fixed: reuse the same arraybuffer for the same array.
    js_id = node"arr => arr"
    @test pointer(js_id(arr1)) ≡ pointer(arr1)
    @test pointer(js_id(arr1)) ≡ pointer(arr1)

    subarr1 = arr1[5:10]
    @test pointer(js_id(subarr1)) ≡ pointer(subarr1)

    delete_context()
end
