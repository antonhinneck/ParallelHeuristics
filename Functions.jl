function toString(data, val)

        output = Vector{String}()

        for i in 1:length(data)
                if length(string(data[i])) <= val
                        push!(output, string(string(data[i])[1:3]))
                else
                        push!(output, string(string(data[i])[1:val]))
                end
        end
        return output
end

function get_iis(m::JuMP.Model)

    @inline function reverse_map(dict)
        keys = collect(keys(dict))
        output = Dict{Any, Any}()
        for i in 1:length(keys)
            push!(output, dict[keys[i]] => keys[i])
        end
        return output
    end

    constraint_indices = collect(keys(backend(m).model_to_optimizer_map.conmap))
    #rev = reverse_map()
    grb_model = backend(m).optimizer.model.inner
    Gurobi.computeIIS(grb_model)
    n_cons = Gurobi.num_constrs(grb_model)

    for c in 1:n_cons
        if Gurobi.get_intattrelement(grb_model, "IISConstr", c) > 0
            print(JuMP.constraint_ref_with_index(m,constraint_indices[c]))
        end
    end
end

function sign_array(arr::S where S <: AbstractArray{T, 1} where T <: Number)

    output = Vector{Float64}()

    for i in 1:length(arr)

        if arr[i] >= 0
            push!(output, 1.0)
        else
            push!(output, -1.0)
        end
    end

    return output
end

function generate_line_vectors(lines; subset = lines, method = :linear, levels = 1)
    line_vectors = Vector{Vector{Int64}}()
    counter = 1
    if method == :linear && levels == 1

        for i in 1:length(lines)
            if lines[i] in Set(subset)
                push!(line_vectors, Vector{Float64}())
                for j in 1:length(lines)
                    if j != i
                        push!(line_vectors[counter], lines[j])
                    end
                end
                counter += 1
            end
        end
    end

    return line_vectors
end
