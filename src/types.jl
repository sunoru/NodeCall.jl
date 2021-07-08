import Base: ==

abstract type NodeValue end

mutable struct NodeValueTemp <: NodeValue
    tempname::String
end

mutable struct NodeObject <: NodeValue
    ref::NapiRef
    function NodeObject(napi_ref)
        ref = new(napi_ref)
        finalizer(ref) do r
            @napi_call napi_delete_reference(getfield(r, :ref)::NapiRef)
        end
        ref
    end
end

NodeObject(value::NapiValue) = NodeObject(
    @napi_call napi_create_reference(value::NapiValue, 1::UInt32)::NapiRef
)

struct NodeError <: NodeValue
    o::NodeObject
end
NodeError(value::NapiValue) = NodeError(NodeObject(value))
Base.show(io::IO, v::NodeError) = print(io, v.message)

const JsUndefined = Nothing
const JsNull = Nothing

const JsBoolean = Bool
const JsNumber = Float64
const JsString = String
const JsBigInt = BigInt
const JsSymbol = Symbol

abstract type JsValue end

abstract type JsObjectType <: JsValue end

struct JsObject <: JsObjectType
    ref::NodeObject
end

struct JsFunction <: JsObjectType
    ref::NodeObject
end

struct JsPromise <: JsObjectType
    ref::NodeObject
    deferred::NapiDeferred
end

struct JsExternal <: JsValue
    ptr::NapiPointer
end

const ValueTypes = Union{NapiValue, NodeValue, JsValue}

Base.get(o::ValueTypes, key; convert_result=true) = open_scope() do _
    v = @napi_call napi_get_property(o::NapiValue, key::NapiValue)::NapiValue
    convert_result ? value(v) : node_value(v)
end
set!(o::ValueTypes, key, value) = open_scope() do _
    @napi_call napi_set_property(o::NapiValue, key::NapiValue, value::NapiValue)::Bool
end
Base.haskey(o::ValueTypes, key) = open_scope() do _
    @napi_call napi_has_property(o::NapiValue, key::NapiValue)::Bool
end
Base.delete!(o::ValueTypes, key) = open_scope() do _
    @napi_call napi_delete_property(o::NapiValue, key::NapiValue)::Bool
end

Base.get(o::ValueTypes, key::AbstractString; convert_result=true) = open_scope() do _
    v = @napi_call napi_get_named_property(o::NapiValue, key::Cstring)::NapiValue
    convert_result ? value(v) : node_value(v)
end
set!(o::ValueTypes, key::AbstractString, value) = open_scope() do _
    @napi_call napi_set_named_property(o::NapiValue, key::Cstring, value::NapiValue)::Bool
end
Base.haskey(o::ValueTypes, key::AbstractString) = open_scope() do _
    @napi_call napi_has_property(o::NapiValue, key::Cstring)::Bool
end
Base.keys(o::ValueTypes) = open_scope() do _
    value(Array, @napi_call napi_get_property_names(o::NapiValue)::NapiValue)
end

Base.get(o::ValueTypes, key::Integer; convert_result=true) = open_scope() do _
    v = @napi_call napi_get_element(o::NapiValue, key::UInt32)::NapiValue
    convert_result ? value(v) : node_value(v)
end
set!(o::ValueTypes, key::Integer, value) = open_scope() do _
    @napi_call napi_set_element(o::NapiValue, key::UInt32, value::NapiValue)::Bool
end
Base.haskey(o::ValueTypes, key::Integer) = open_scope() do _
    @napi_call napi_has_element(o::NapiValue, key::UInt32)::Bool
end
Base.delete!(o::ValueTypes, key::Integer) = open_scope() do _
    @napi_call napi_delete_element(o::NapiValue, key::UInt32)::Bool
end

Base.getproperty(o::ValueTypes, key::Symbol) = get(o, string(key))
Base.setproperty!(o::ValueTypes, key::Symbol, value) = set!(o, string(key), value)
Base.hasproperty(o::ValueTypes, key::Symbol) = haskey(o, string(key))
Base.propertynames(o::ValueTypes) = Symbol.(keys(o))
Base.getindex(o::ValueTypes, key) = get(o, key)
Base.setindex!(o::ValueTypes, key, value) = set!(o, key, value)

Base.show(io::IO, v::NodeValueTemp) = print(io, string("NodeValueTemp: ", getfield(v, :tempname)))
Base.show(io::IO, v::NodeObject) = print(io, string("NodeObject: ", getfield(v, :ref)))
Base.show(io::IO, v::JsObjectType) = print(io, string(typeof(v), ": ", UInt64(pointer_from_objref(getfield(v, :ref)))))
Base.show(io::IO, v::JsExternal) = print(io, string(typeof(v), ": ", getfield(v, :ptr)))

Base.length(v::ValueTypes) = Int(open_scope() do _
    nv = NapiValue(v)
    if is_typedarray(nv)
        typedarray_info(nv).length
    elseif is_arraybuffer(nv)
        arraybuffer_info(nv).length
    else
        @napi_call napi_get_array_length(nv::NapiValue)::UInt32
    end
end)

get_type(v::ValueTypes) = @napi_call napi_typeof(v::NapiValue)::NapiValueType
instanceof(a::ValueTypes, b::ValueTypes) = @with_scope try
    @napi_call napi_instanceof(a::NapiValue, b::NapiValue)::Bool
catch _
    false
end

# Call
(func::ValueTypes)(args...; recv=nothing, convert_result=true) = open_scope() do _
    recv = isnothing(recv) ? _get_global() : recv
    argc = length(args)
    argv = argc == 0 ? C_NULL : NapiValue.(collect(args))
    result = @napi_call napi_call_function(recv::NapiValue, func::NapiValue, argc::Csize_t, argv::Ptr{NapiValue})::NapiValue
    convert_result ? value(result) : result
end

==(a::ValueTypes, b::ValueTypes) = @with_scope try
    @napi_call napi_strict_equals(a::NapiValue, b::NapiValue)::Bool
catch _
    false
end
