using Test, NodeCall
using Pkg

if dirname(Pkg.project().path) != @__DIR__
    Pkg.activate(@__DIR__)
end

if !NodeCall.initialized()
    NodeCall.initialize()
end
