
function toStep(x, y)
    @assert(length(x) == length(y))
    x_step = Vector{eltype(x)}()
    y_step = Vector{eltype(y)}()

    for i in 1:length(x)
        if i == 1
            push!(x_step, x[i])
        else
            push!(x_step, x[i])
            push!(x_step, x[i])
        end
    end

    for i in 1:length(y)
        if i == length(x)
            push!(y_step, y[i])
        else
            push!(y_step, y[i])
            push!(y_step, y[i])
        end
    end

    return x_step, y_step
end