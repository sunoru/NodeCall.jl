using NodeCall

NodeCall.initialize()

@node_import { scrypt, randomFill, createCipheriv } from "crypto"

algorithm = "aes-192-cbc"
password = "some password"

# Very important: let arrays be passed by value to let node handle the memory.
# because `crypto` doesn't work with external `ArrayBuffer`s.
set_copy_array(true)

ch = Channel{String}(1)
scrypt(password, "salt", 24, (err, key) -> begin
    isnothing(err) || throw(err)
    randomFill(zeros(UInt8, 16), (err, iv) -> begin
        isnothing(err) || throw(err)
        cipher = createCipheriv(algorithm, key, iv)
        encrypted = ""
        cipher.setEncoding("hex")
        cipher.on("data", (chunk) -> (@info "on data"; encrypted *= chunk))
        cipher.on("end", () -> (@info "on end"; put!(ch, encrypted)))
        cipher.write("Some clear text data")
        cipher.end()
    end)
end)

encrypted = @await @async take!(ch)
@show encrypted
