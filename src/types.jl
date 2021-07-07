struct JlnodeResult
    code::Cint
    message::Cstring
end
JlnodeResult() = JlnodeResult(0, C_NULL)

isok(result::JlnodeResult) = result.code == 0
function Base.show(io::IO, result::JlnodeResult)
    print(io, "Result Code: $(result.code)")
    if !isok(result) && result.message != C_NULL
        print(io, "\nMessage: $(unsafe_string(result.message))")
    end
end

const _GLOBAL_RESULT = Ref(JlnodeResult())
global_result() = _GLOBAL_RESULT

struct NapiValue
    env::NapiEnv
    pointer::Ptr{Cvoid}
end

mutable struct NodeValue
    env::NapiEnv
    tempname::String
end

function NapiValue(
    raw::NapiValue,
    tempname = uuid4(global_rng())
)
    env = raw.env
    tempvar = get_tempvar(env)
    @libjlnode_call object_set_property_str(env, tempvar, tempname, raw.pointer)
    NapiValue(raw.env, tempname)
end

# Use mutable struct to make use of `finalizer`.
mutable struct NapiRef
    napi_ref::NapiValue
end

const JsUndefined = Nothing
const JsNull = Nothing

const JsBoolean = Bool
const JsNumber = Float64
const JsString = String
const JsBigInt = BigInt
const JsSymbol = Symbol

mutable struct JsObject{T <: Union{Nothing, String}}
    ptr::Ptr{Nothing}
    tempname::T
end

mutable struct JsFunction{T <: Union{Nothing, String}}
    ptr::Ptr{Nothing}
    tempname::T
end
