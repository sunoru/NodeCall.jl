const CurrentTasks = Set{Task}()  # Dict{Task, Task}()
function threadsafe_call(f::Function)
    ct = current_task()
    @show ct
    @show stacktrace()
    # if ct ∈ keys(CurrentTasks)
    if ct ∈ CurrentTasks
        return f()
    end
    # CurrentTasks[ct] = @async begin
    #     wait(ct)
    #     deleteat!(CurrentTasks, ct)
    # end
    push!(CurrentTasks, ct)
    channel = Channel(1)
    f_ptr = pointer(reference(f))
    c_ptr = pointer(reference(channel))
    status = @napi_call true create_threadsafe_function(
        f_ptr::Ptr{Cvoid}, c_ptr::Ptr{Cvoid}
    )
    if status != NapiTypes.napi_ok
        error(status)
    end
    result = take!(channel)
    dereference(f_ptr)
    dereference(c_ptr)
    pop!(CurrentTasks, ct)
    @show result
    result
end
