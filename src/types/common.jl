get_type(v::ValueTypes) = @napi_call napi_typeof(v::NapiValue)::NapiValueType

instanceof(a::ValueTypes, b::ValueTypes) = @with_scope try
    @napi_call napi_instanceof(a::NapiValue, b::NapiValue)::Bool
catch _
    false
end

macro wrap_is_type(name)
    func_name = Symbol(:is_, name)
    napi_name = Symbol(:napi_, func_name)
    @eval $func_name(v::NapiValue) = @napi_call $napi_name(v::NapiValue)::Bool
    @eval $func_name(v::ValueTypes) = @with_scope $func_name(NapiValue(v))
end

@wrap_is_type array
@wrap_is_type arraybuffer
@wrap_is_type buffer
@wrap_is_type date
@wrap_is_type error
@wrap_is_type typedarray
@wrap_is_type dataview
@wrap_is_type promise

const _js_map = Ref{NodeObject}()
is_map(v::NapiValue) = instanceof(v, _js_map[])
const _js_set = Ref{NodeObject}()
is_set(v::NapiValue) = instanceof(v, _js_set[])

function _initialize_types()
    _js_map[] = node"Map"o
    _js_set[] = node"Set"o
end

macro wrap_coerce_convert(name)
    func_name = Symbol(:to_, name)
    napi_name = Symbol(:napi_coerce_, func_name)
    @eval $func_name(v::ValueTypes) = @napi_call $napi_name(v::NapiValue)::NapiValue
end

@wrap_coerce_convert bool
@wrap_coerce_convert number
@wrap_coerce_convert object
@wrap_coerce_convert string

Base.show(io::IO, v::JsObjectType) = print(io, string(
    typeof(v), ": ",
    string_pointer(getfield(v, :ref))
))

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
