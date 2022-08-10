using NodeCall

NodeCall.initialize()

const http = require("http")

const hostname = "127.0.0.1"
const port = 3000

const server = http.createServer((req, res) -> begin
    res.statusCode = 200
    res.setHeader("Content-Type", "text/plain")
    res.end("Hello, World!\n")
end)

url = "http://$hostname:$port/"
server.listen(port, hostname, () -> begin
    println("Server running at $url")
end)

@async @threadsafe begin
    println("Trying to access $url")
    http.get("$url", (res) -> begin
        res.setEncoding("utf8")
        res.on("data", (chunk) -> println("Receive data: ", chunk))
    end)
end
