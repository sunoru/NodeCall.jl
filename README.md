# NodeCall.jl

[![CI Test](https://github.com/sunoru/NodeCall.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/sunoru/NodeCall.jl/actions/workflows/CI.yml)
[![codecov](https://codecov.io/gh/sunoru/NodeCall.jl/branch/main/graph/badge.svg?token=8VQGZEMHAI)](https://codecov.io/gh/sunoru/NodeCall.jl)

Call NodeJS from Julia.

Currently supports NodeJS v16 (Latest LTS).

## Dependency

This package depends on [`libnode_jll.jl`](https://github.com/JuliaBinaryWrappers/libnode_jll.jl)
and [`libjlnode_jll.jl`](https://github.com/JuliaBinaryWrappers/libjlnode_jll.jl).

You need to have Julia v1.7+ installed to use this package.

## Installation

`NodeCall.jl` has not been registered yet, so you need to manually install it by its git source:

```julia
(v1.7) pkg> add https://github.com/sunoru/NodeCall.jl
```

You can then run the tests by:
```julia
(v1.7) pkg> test NodeCall
```

## Usage

With `using NodeCall`, a NodeJS instance will start in the current process. A new V8 Virtual Machine context
([`vm`](https://nodejs.org/docs/latest-v16.x/api/vm.html) in the standard library of NodeJS)
is automatically created.

And JavaScript code can be run with `node_eval` or `@node_str`
(they are equivalent except the latter supports interpolation):

```julia
julia> using NodeCall

julia> node_eval("console.log('Hello, world!')")
Hello, world!

julia> x = 5
julia> node"2 * $x"
10.0
```

You can directly use `require` to use Node APIs.
```julia
julia> os = require("os");

julia> os.type()
"Linux"
```

To install a NPM package, use something like this:
```julia
julia> NPM.install("boxen");

added 19 packages, and audited 20 packages in 683ms

11 packages are looking for funding
  run `npm fund` for details

found 0 vulnerabilities
```
Note that it is equivalent to running `npm install` in the current working directory, but with
the specific version of NodeJS provided by `NodeCall.jl`.

And then you can use the installed package as if you are writing JavaScript.
In this example, `node_import` or `@node_import` should be used since `boxen` is an ES Module.

```julia
# `node_import` is like the function-like dynamic import in js, so it is asynchronous and should be awaited.
julia> boxen = (@await node_import("boxen")).default;

# or you can use module style import declaration with `@node_import` macro.
julia> @node_import boxen from "boxen";

julia> boxen("Generated in JS") |> println
┌───────────────┐
│Generated in JS│
└───────────────┘

# To pass an option object, the easiest way is to use a `NamedTuple` in Julia:
julia> boxen("Passing options", (padding=1, borderStyle="double")) |> println
╔═════════════════════╗
║                     ║
║   Passing options   ║
║                     ║
╚═════════════════════╝

# Alternatively, you can just use a node string:
julia> boxen("Passing a JS Object", node"{padding: 1}") |> println
┌─────────────────────────┐
│                         │
│   Passing a JS Object   │
│                         │
└─────────────────────────┘
```

See [`examples/`](./examples) or [`test/runtests.jl`](./test/runtests.jl) for more examples.

## Known Issues

~~One important problem of `NodeCall.jl` is that it cannot work with Julia's
multi-thread/process functions, as well as the asynchronous methods involving `Task`s.
However, asynchronous features in NodeJS (`Promise`s) works fine by
awaiting them explicitly.~~

You can now use `@threadsafe f(args...)` to make/call a function in a threadsafe manner.

You have to use `@await` instead of `wait` or `fetch` to wait for a `Task` to finish if
the `Task` accesses the NodeJS environment, since it calls `run_node_uvloop` automatically.

Another way to asynchronously access the NodeJS environment is to use `@node_async`.
`@node_async` works like `@async` in Julia, but instead of scheduling a `Task` in Julia,
it creates a `JsPromise` to wait on. Thus, the tasks are managed by the NodeJS side.

`jl_yield()` is automatically called in NodeJS' event loop, so it won't block other `Task`s in Julia.

## Bug Reports & Contributing

Please feel free to file issues and pull requests. Any feedback or help would be greatly appriciated.

To contribute, you can firstly have a look at the [TODO list](https://github.com/sunoru/NodeCall.jl/issues/3).

It may also be helpful to edit the C++ code in [jlnode](https://github.com/sunoru/jlnode)
to define some utility functions.
It is mainly because in pure Julia it is difficult to handle pointers, especially those of functions.

## License

[MIT License](./LICENSE.md)
