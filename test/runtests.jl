include("test_common.jl")

@testset "NodeCall.jl" begin
    include("executables.jl")

    NodeCall.initialize()

    include("types.jl")
    include("eval.jl")
    include("objects.jl")
    include("arrays.jl")
    include("functions.jl")
    include("promises.jl")
    include("import.jl")
    include("external.jl")
    include("internals.jl")
    include("contexts.jl")

    NodeCall.dispose()
end
