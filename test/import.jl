include("test_common.jl")

@testset "import" begin
    # Not support
    # node"import path from 'path'"
    path = require("path")
    @test path == node"require('path')"
    @test path.resolve(".") == abspath(".")[1:end-1]
    node"const fs = require('fs')"

    cd(@__DIR__)
    ensure_dynamic_import(context=current_context())
    isfile("package.json") || NPM.init("-y")
    # Test with `bcrypt` that is a npm package with native dependencies.
    NPM.is_installed("bcrypt") || NPM.install("bcrypt")
    @node_import bcrypt from "bcrypt"
    @node_import bcrypt2, { hash: bcrypt_hash } from "bcrypt"
    @test bcrypt_hash == bcrypt.hash
    @test bcrypt == bcrypt2
    pass = "somePlainTextPassword"
    hash = @await bcrypt_hash(pass, 10)
    @test @await bcrypt.compare(pass, hash)
    @test !(@await bcrypt.compare("other password", hash))
end
