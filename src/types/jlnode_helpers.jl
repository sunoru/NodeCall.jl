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
_jlnode_propertynames(o::Module) = string.(names(o))
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

function jlnode_call_threadsafe(f_ptr::Ptr{Cvoid})
    f = get_reference(f_ptr)[]
    f()
    nothing
end

jlnode_external_finalizer(ptr::Ptr{Cvoid}) = (external_finalizer(ptr); nothing)
jlnode_object_finalizer(f_ptr::Ptr{Cvoid}, data_ptr::Ptr{Cvoid}) = (object_finalizer(f_ptr, data_ptr); nothing)
jlnode_arraybuffer_finalizer(ptr::Ptr{Cvoid}) = (arraybuffer_finalizer(ptr); nothing)

struct _JlnodeUtilFunctions
    jl_yield::Ptr{Cvoid}
    propertynames::Ptr{Cvoid}
    getproperty::Ptr{Cvoid}
    setproperty::Ptr{Cvoid}
    hasproperty::Ptr{Cvoid}
    external_finalizer::Ptr{Cvoid}
    object_finalizer::Ptr{Cvoid}
    arraybuffer_finalizer::Ptr{Cvoid}
    call_function::Ptr{Cvoid}
    call_threadsafe::Ptr{Cvoid}
end

const _jlnode_util_functions() = _JlnodeUtilFunctions(
    cglobal(:jl_yield),
    @cfunction(jlnode_propertynames, NapiValue, (Ptr{Cvoid},)),
    @cfunction(jlnode_getproperty, NapiValue, (Ptr{Cvoid}, Ptr{Cvoid})),
    @cfunction(jlnode_setproperty!, NapiValue, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid})),
    @cfunction(jlnode_hasproperty, NapiValue, (Ptr{Cvoid}, Ptr{Cvoid})),
    @cfunction(jlnode_external_finalizer, Cvoid, (Ptr{Cvoid},)),
    @cfunction(jlnode_object_finalizer, Cvoid, (Ptr{Cvoid}, Ptr{Cvoid})),
    @cfunction(jlnode_arraybuffer_finalizer, Cvoid, (Ptr{Cvoid},)),
    @cfunction(call_function, NapiValue, (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t, Ptr{Cvoid})),
    @cfunction(jlnode_call_threadsafe, Cvoid, (Ptr{Cvoid},))
)
