_convert_key(::AbstractDict{T}, k::T) where T = k
_convert_key(::AbstractDict{String}, k) = string(k)
_convert_key(::AbstractDict{String}, k::String) = k
_convert_key(::AbstractDict{T}, k::AbstractString) where T <: Number = T(
    if isconcretetype(T)
        parse(T, k)
    else
        parse(Float64, k)
    end
)
_convert_key(::AbstractDict{T}, k) where T = convert(T, k)

_jlnode_getproperty(o, k) = getproperty(o, Symbol(k))
_jlnode_getproperty(o::AbstractDict, k) = getindex(o, _convert_key(o, k))
function jlnode_getproperty(o_ptr::Ptr{Cvoid}, k_ptr::Ptr{Cvoid})
    o = get_reference(o_ptr)[]
    k = value(convert(NapiValue, k_ptr))
    _jlnode_getproperty(o, k) |> napi_value
end

_jlnode_setproperty!(o, k, v) = setproperty!(o, Symbol(k), v)
_jlnode_setproperty!(o::AbstractDict, k, v) = setindex!(o, v, _convert_key(o, k))
function jlnode_setproperty!(o_ptr::Ptr{Cvoid}, k_ptr::Ptr{Cvoid}, v_ptr::Ptr{Cvoid})
    o = get_reference(o_ptr)[]
    k = value(convert(NapiValue, k_ptr))
    v = value(convert(NapiValue, v_ptr))
    _jlnode_setproperty!(o, k, v) |> napi_value
end


_jlnode_propertynames(o) = string.(propertynames(o))
_jlnode_propertynames(o::AbstractDict) = keys(o)
_jlnode_propertynames(o::Module) = names(o)
jlnode_propertynames(o_ptr::Ptr{Cvoid}) = let o = get_reference(o_ptr)[]
    _jlnode_propertynames(o) |> napi_value
end

_jlnode_hasproperty(o, k) = hasproperty(o, Symbol(k))
_jlnode_hasproperty(o::AbstractDict, k) = try
    haskey(o, _convert_key(o, k))
catch
    false
end
function jlnode_hasproperty(o_ptr::Ptr{Cvoid}, k_ptr::Ptr{Cvoid})
    o = get_reference(o_ptr)[]
    k = value(convert(NapiValue, k_ptr))
    _jlnode_hasproperty(o, k) |> napi_value
end
