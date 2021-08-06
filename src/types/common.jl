get_type(v::ValueTypes) = @napi_call napi_typeof(v::NapiValue)::NapiValueType

instanceof(a, b) = @with_scope try
    @napi_call napi_instanceof(a::NapiValue, b::NapiValue)::Bool
catch _
    false
end

is_undefined(nv::NapiValue) = get_type(nv) == NapiTypes.napi_undefined
is_function(nv::NapiValue) = get_type(nv) == NapiTypes.napi_function

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

@global_js_const _JS_MAP = "Map"
is_map(v::NapiValue) = instanceof(v, _JS_MAP)
@global_js_const _JS_SET = "Set"
is_set(v::NapiValue) = instanceof(v, _JS_SET)
@global_js_const _JS_ITERATOR_SYMBOL = "Symbol.iterator" false
is_iterator(v::NapiValue) = is_function(get(v, _JS_ITERATOR_SYMBOL, nothing; raw=true))

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
    # value(String, getfield(v, :ref))
))

function Base.get(
    o::ValueTypes, key, default=nothing;
    raw=false, convert_result=true
)
    with_result(raw, convert_result, this=o) do
        nv = @napi_call napi_get_property(o::NapiValue, key::NapiValue)::NapiValue
        is_undefined(nv) && return default
        nv
    end
end
set!(o::ValueTypes, key, value) = @with_scope begin
    @napi_call napi_set_property(o::NapiValue, key::NapiValue, value::NapiValue)
end
Base.haskey(o::ValueTypes, key) = @with_scope begin
    @napi_call napi_has_property(o::NapiValue, key::NapiValue)::Bool
end
Base.delete!(o::ValueTypes, key) = @with_scope begin
    @napi_call napi_delete_property(o::NapiValue, key::NapiValue)::Bool
end

Base.get(
    o::ValueTypes, key::AbstractString, default=nothing;
    raw=false, convert_result=true
) = with_result(raw, convert_result, this=o) do
    nv = @napi_call napi_get_named_property(o::NapiValue, key::Cstring)::NapiValue
    is_undefined(nv) && return default
    nv
end
set!(o::ValueTypes, key::AbstractString, value) = @with_scope begin
    @napi_call napi_set_named_property(o::NapiValue, key::Cstring, value::NapiValue)
end
Base.haskey(o::ValueTypes, key::AbstractString) = @with_scope begin
    @napi_call napi_has_property(o::NapiValue, key::Cstring)::Bool
end
Base.keys(o::ValueTypes) = @with_scope begin
    value(Array, @napi_call napi_get_property_names(o::NapiValue)::NapiValue)
end

Base.get(
    o::ValueTypes, key::Integer, default=nothing;
    raw=false, convert_result=true
) = with_result(raw, convert_result, this=o) do
    nv = @napi_call napi_get_element(o::NapiValue, key::UInt32)::NapiValue
    is_undefined(nv) && return default
    nv
end
set!(o::ValueTypes, key::Integer, value) = @with_scope begin
    @napi_call napi_set_element(o::NapiValue, key::UInt32, value::NapiValue)
end
Base.haskey(o::ValueTypes, key::Integer) = @with_scope begin
    @napi_call napi_has_element(o::NapiValue, key::UInt32)::Bool
end
Base.delete!(o::ValueTypes, key::Integer) = @with_scope begin
    @napi_call napi_delete_element(o::NapiValue, key::UInt32)::Bool
end

Base.getproperty(o::ValueTypes, key::Symbol) = get(o, string(key))
Base.setproperty!(o::ValueTypes, key::Symbol, value) = set!(o, string(key), value)
Base.hasproperty(o::ValueTypes, key::Symbol) = haskey(o, string(key))
Base.propertynames(o::ValueTypes) = Symbol.(keys(o))
Base.getindex(o::ValueTypes, key) = get(o, key)
Base.setindex!(o::ValueTypes, value, key) = set!(o, key, value)

_convert_key(::AbstractDict{T}, k::T) where T = k
_convert_key(::AbstractDict{String}, k) = string(k)
_convert_key(::AbstractDict{T}, k::AbstractString) where T <: Number = T(
    if isconcretetype(T)
        parse(T, k)
    else
        parse(Float64, k)
    end
)
_convert_key(::AbstractDict{T}, k) where T = convert(T, k)

@noinline jlnode_getproperty(o, k) = getproperty(o, Symbol(k))
@noinline jlnode_getproperty(o::AbstractDict, k) = getindex(o, _convert_key(o, k))
@noinline jlnode_setproperty!(o, k, v) = setproperty!(o, Symbol(k), v)
@noinline jlnode_setproperty!(o::AbstractDict, k, v) = setindex!(o, v, _convert_key(o, k))
@noinline jlnode_propertynames(o) = string.(propertynames(o))
@noinline jlnode_propertynames(o::AbstractDict) = keys(o)
@noinline jlnode_propertynames(o::Module) = names(o)
@noinline jlnode_hasproperty(o, k) = hasproperty(o, Symbol(k))
@noinline jlnode_hasproperty(o::AbstractDict, k) = try
    haskey(o, _convert_key(o, k))
catch
    false
end
