using NodeCall

const http = require("http")

const hostname = "127.0.0.1"
const port = 3000

const server = http.createServer((req, res) -> begin
    res.statusCode = 200
    res.setHeader("Content-Type", "text/plain")
    res.end("Hello, World!\n")
end)

server.listen(port, hostname, () -> begin
    println("Server running at http://$hostname:$port/")
end)

run_node_uvloop()
