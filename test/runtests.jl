include("test_common.jl")

@testset "NodeCall.jl" begin
    NodeCall.initialize()

    include("types.jl")
    include("eval.jl")
    include("objects.jl")
    include("arrays.jl")
    include("functions.jl")
    include("promises.jl")
    include("import.jl")
    include("internals.jl")
    include("contexts.jl")
    include("miscs.jl")

    NodeCall.dispose()
end
