get_type(v::NapiValue) = @napi_call napi_typeof(v::NapiValue)::NapiValueType

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
end

@wrap_is_type array
@wrap_is_type arraybuffer
@wrap_is_type buffer
@wrap_is_type typedarray
@wrap_is_type dataview
@wrap_is_type date
@wrap_is_type error
@wrap_is_type promise

@global_js_const _JS_MAP = "Map"
is_map(v::NapiValue) = instanceof(v, _JS_MAP)
@global_js_const _JS_SET = "Set"
is_set(v::NapiValue) = instanceof(v, _JS_SET)
@global_js_const _JS_ITERATOR_SYMBOL = "Symbol.iterator" false
is_iterator(v::NapiValue) = is_function(get(v, _JS_ITERATOR_SYMBOL, nothing; result=RESULT_RAW))

for func in (
    :get_type,
    :is_array, :is_arraybuffer, :is_buffer,
    :is_typedarray, :is_dataview,
    :is_date, :is_error,
    :is_promise,
    :is_map, :is_set, :is_iterator
)
    @eval $func(v) = @with_scope $func(napi_value(v))
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

function Base.get(
    o::ValueTypes, key, default=nothing;
    result=RESULT_VALUE
)
    with_result(result, this=o) do
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
Base.in(key, o::ValueTypes) = haskey(o, key)

Base.get(
    o::ValueTypes, key::AbstractString, default=nothing;
    result=RESULT_VALUE
) = with_result(result, this=o) do
    nv = @napi_call napi_get_named_property(o::NapiValue, key::Cstring)::NapiValue
    is_undefined(nv) && return default
    nv
end
set!(o::ValueTypes, key::AbstractString, value) = @with_scope begin
    @napi_call napi_set_named_property(o::NapiValue, key::Cstring, value::NapiValue)
end
Base.haskey(o::ValueTypes, key::AbstractString) = @with_scope begin
    @napi_call napi_has_named_property(o::NapiValue, key::Cstring)::Bool
end
Base.keys(o::ValueTypes) = @with_scope begin
    value(Array, @napi_call napi_get_property_names(o::NapiValue)::NapiValue)
end

Base.get(
    o::ValueTypes, key::Integer, default=nothing;
    result=RESULT_VALUE
) = with_result(result, this=o) do
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
Base.propertynames(o::ValueTypes) = Tuple(Symbol.(keys(o)))
Base.getindex(o::ValueTypes, key) = get(o, key)
Base.setindex!(o::ValueTypes, value, key) = set!(o, key, value)
