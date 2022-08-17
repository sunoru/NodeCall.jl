using NodeCall

cd(@__DIR__)
NodeCall.initialize()

# Install `node-fetch` with `npm`.
NPM.install()

# Use dynamic import to load ES modules like `node-fetch`.
ensure_dynamic_import()
@node_import jsfetch from "node-fetch"
const console = node"console"

# `fetch` is Julia's `await`
response = fetch(jsfetch("https://ip.sunoru.com"))

# Or you can use the await macro
ip = @await response.text()

@show ip

# Define an asynchronous function in JS scripts.
# Note that the imported `fetch` should be manually passed in.
f1 = node"""async (fetch) => {
    const response = await fetch('https://httpbin.org/post', {method: 'POST', body: 'a=1'})
    const data = await response.json()
    return data
}"""

p = f1(jsfetch).then() do data
    # We can use Julia's do-block to pass the function to `then()`
    @show data
    console.log(data)
    for k in keys(data)
        v = data[k]
        if v isa JsObject
            v = value(Dict, v)
        end
        @show k, v
    end
    throw("Some error in promise")
end.catch() do err
    # The `catch()` method is similar.
    @show err
    console.error("Catched: \n", err)
end

# Should explicitly wait for the promise to complete.
wait(p)
