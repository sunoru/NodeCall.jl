using RandomNumbers.Xorshifts: Xoshiro256StarStar

const _GLOBAL_RNG = Xoshiro256StarStar()
global_rng() = _GLOBAL_RNG

macro libjlnode_call(func)
    quote
        status = @ccall :libjlnode.$func
        if status == 0
    end
end

const tmpvar_name = "__jlnode_tmp"
get_global(env) = @libjlnode_call env_get_global(env)
get_tempvar(env) = let _global = env_get_global(env)
    @libjlnode_call object_get_property_names(_global, tempvar_name)
end
