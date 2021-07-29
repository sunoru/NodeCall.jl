# NodeCall.jl

[![CI Test](https://github.com/sunoru/NodeCall.jl/actions/workflows/build.yml/badge.svg)](https://github.com/sunoru/NodeCall.jl/actions/workflows/build.yml)
[![codecov](https://codecov.io/gh/sunoru/NodeCall.jl/branch/main/graph/badge.svg?token=8VQGZEMHAI)](https://codecov.io/gh/sunoru/NodeCall.jl)

Call NodeJS from Julia.

Currently only supports NodeJS v14.17.3 (LTS).

## Dependency

This package depends on [`libnode_jll.jl`](https://github.com/JuliaBinaryWrappers/libnode_jll.jl) 
and [`libjlnode_jll.jl`](https://github.com/JuliaBinaryWrappers/libjlnode_jll.jl).

You need to have Julia v1.6+ installed to use this package.

## Installation

`NodeCall.jl` has not been registered yet, so you need to manually install it by its git source:

```julia
(v1.6) pkg> add https://github.com/sunoru/NodeCall.jl
```

You can then run the tests by:
```julia
(v1.6) pkg> test NodeCall
```

## Usage

With `using NodeCall`, a NodeJS instance will start in the current process. A new V8 Virtual Machine context
([`vm`](https://nodejs.org/docs/latest-v14.x/api/vm.html) in the standard library of NodeJS)
is automatically created.

And JavaScript code can be run with `run_script` or `@node_str` (they are equivalent):

```julia
julia> using NodeCall

julia> node"console.log('Hello, world')"
Hello, world

julia> run_script("123 * 456")
56088.0
```

To install a NPM package, use something like this:
```julia
julia> run(npm("install", "boxen"));
+ boxen@5.0.1
added 19 packages from 3 contributors and audited 26 packages in 0.782s

7 packages are looking for funding
  run `npm fund` for details

found 0 vulnerabilities
```
Note that it is equivalent to running `npm install` in the current working directory, but with
the specific version of NodeJS provided by `NodeCall.jl`.

And then you can use the installed package as if you are writing JavaScript.

```julia
julia> boxen = require("boxen");

julia> println(boxen("Generated in JS"))
┌───────────────┐
│Generated in JS│
└───────────────┘

# To pass an option object, you can use a `Dict{String, Any}` in Julia:
julia> println(boxen("Dict as Object", Dict("padding"=>1, "borderStyle"=>"double")))
╔════════════════════╗
║                    ║
║   Dict as Object   ║
║                    ║
╚════════════════════╝

# Or more easily, you can just use a node string
julia> println(boxen("Pass JS Object", node"{padding: 1}"))
┌────────────────────┐
│                    │
│   Pass JS Object   │
│                    │
└────────────────────┘
```

See [`examples/`](./examples) or [`test/runtests.jl`](./test/runtests.jl) for more examples.

## Bug Reports & Contributing

Please feel free to file issues and pull requests. Any feedback or help would be greatly appriciated.

To contribute, you can firstly have a look at the [TODO list](https://github.com/sunoru/NodeCall.jl/issues/3).

It may also be helpful to edit the C++ code in [jlnode](https://github.com/sunoru/jlnode)
to define some utility functions.
It is mainly because in pure Julia it is difficult to handle pointers, especially those of functions.

## License

[MIT License](./LICENSE.md)
