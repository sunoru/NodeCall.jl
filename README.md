# NodeCall.jl

Call NodeJS from Julia.

WIP.

## Dependency

`libjlnode_jll.jl`.

## Usage

## Examples
See [`test/runtests.jl`](./test/runtests.jl) for examples.

## TODO

- Avoid creating arraybuffer for same Julia array more than once.
- Pack `libjlnode_jll.jl` by compiling [`jlnode`](https://github.com/sunoru/jlnode).
- Add CI.
- Implement interface for asynchronous functions as well as generators.
- Make use of multiple threads/processes (worker threads in node).
- Clean possibly messy code.
- More utility functions (such as executing npm, running with multiple contexts).

## LICENSE

[MIT License](./LICENSE.md)
