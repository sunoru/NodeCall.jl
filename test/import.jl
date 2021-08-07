include("test_common.jl")

@testset "import" begin
    # Not support
    # node"import path from 'path'"
    path = require("path")
    @test path == node"require('path')"
    @test path.resolve(".") == abspath(".")[1:end-1]
    node"const fs = require('fs')"

    cd(@__DIR__)
    isfile("package.json") || run(npm`init -y`)
    # Test with `canvas` that is a npm package with native dependencies.
    run(npm`install canvas`)
    canvas_module = require("canvas")
    canvas = canvas_module.createCanvas(10, 10)
    ctx = canvas.getContext("2d")
    ctx.strokeStyle = "rgba(0,0,0,0.5)"
    ctx.beginPath()
    ctx.lineTo(1, 7)
    ctx.lineTo(10, 3)
    ctx.stroke()
    @test canvas.toDataURL() == "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAKCAYAAACNMs+" *
        "9AAAABmJLR0QA/wD/AP+gvaeTAAAAV0lEQVQYla3PsQ1AAABE0aehYQAliQEkJHaxroROYgUWEJ1Ko1AgCr/+" * 
        "l7vjb4KPTvYmhijRYLsTY1SosaDDfBXTM11gQo/12h+hRYIBI/anPblvx37kANwUCq3OvPHeAAAAAElFTkSuQmCC"
end
