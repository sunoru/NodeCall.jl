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

    delete_context()
end
