@global_js_const _JS_MAKE_ASYNC = "(f) => new Promise((resolve, reject) => {
    setTimeout(() => {
        try {
            resolve(f())
        } catch (e) {
            reject(e)
        }
    }, 0)
})"

macro node_async(expr)
    letargs = Base._lift_one_interp!(expr)
    thunk = esc(:(()->($expr)))
    quote
        let $(letargs...)
            _JS_MAKE_ASYNC($thunk)
        end
    end
end
