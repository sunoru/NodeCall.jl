using NodeCall

run(npm("install", "@babel/core", "@babel/preset-typescript"))

const babel = require("@babel/core")

function run_ts(ts_script)
    options = node"""{
        filename: "file.ts",
        presets: ["@babel/preset-typescript"]
    }"""
    result = @await babel.transformAsync(ts_script, options)
    run_script(result.code)
end

run_ts("""
interface Box<T> {
    contents: T
}
type StrBox = Box<string>
const box1: Box<number> = { contents: 20070128 }
const box2: StrBox = { contents: "Hello, world!" }
const print1 = (box: Box<number>): void => {
    console.log("Number box: ", box)
}
const print2 = (box: StrBox): void => {
    console.log("String box: ", box)
}""")
print1, print2, box1, box2 = node"[print1, print2, box1, box2]"

print1(box1)
print2(box2)
