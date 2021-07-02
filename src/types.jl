const JsUndefined = Nothing
const JsNull = Nothing

const JsBoolean = Bool
const JsNumber = Float64
const JsString = String
const JsBigInt = BigInt
const JsSymbol = Symbol

# Use mutable struct to make use of `finalizer`.
mutable struct JsObject{T} where T <: Union{Nothing, String}
    ptr::Ptr{Nothing}
    tempname::T
end

mutable struct JsFunction{T} where T <: Union{Nothing, String}
    ptr::Ptr{Nothing}
    tempname::T
end
