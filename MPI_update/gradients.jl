function gradient(start::RGBA, stop::RGBA, n_el::T where T <: Integer)

    grad = Vector{RGBA}()

    stepsize_r = (stop.r - start.r) / n_el
    stepsize_g = (stop.g - start.g) / n_el
    stepsize_b = (stop.b - start.b) / n_el

    push!(grad, start)

    current = [start.r, start.g, start.b, 1.0]
    for i in 1:(n_el - 1)
        current[1] += stepsize_r
        current[2] += stepsize_g
        current[3] += stepsize_b
        push!(grad, RGBA(current...))
    end

    grad_rgba = Vector{Tuple{Float64, Float64, Float64, Float64}}()
    grad_rgb = Vector{Tuple{Float64, Float64, Float64}}()
    for i in 1:length(grad)
        push!(grad_rgba, ((grad[i].r, grad[i].g, grad[i].b, 1.0)))
        push!(grad_rgb, ((grad[i].r, grad[i].g, grad[i].b)))
    end

    return grad, grad_rgba, grad_rgb
end
