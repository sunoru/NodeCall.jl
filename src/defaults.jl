for func in (
    :get_tempvar,
    :node_value,
    :run, :require
)

@eval $func(args...; kwargs...) = $func(global_env(), args...; kwargs...)
@eval $func(args...; kwargs...) = $func(global_env(), args...; kwargs...)

end
