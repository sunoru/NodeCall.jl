using NodeCall

NodeCall.initialize()

cd(@__DIR__)
# Install babel to transpile TypeScript.
run(npm`install`)
const babel = require("@babel/core")

# Run scripts in TS.
function run_ts(ts_script)
    options = node"""{
        filename: "file.ts",
        presets: ["@babel/preset-typescript"]
    }"""
    result = @await babel.transformAsync(ts_script, options)
    node_eval(result.code)
end

run_ts("""
interface Box<T> {
    contents: T
}
class BoxClass<T> implements Box<T> {
    public constructor(
        public contents: T
    ) { }
    public print(): void {
        console.log("this.contents =", this.contents)
    }
}
const box1: BoxClass<number> = new BoxClass(20070128)
const box2: Box<string> = new BoxClass("Hello, world!")
""")
box1, box2 = node"[box1, box2]"

@show box1.contents
box2.print()
