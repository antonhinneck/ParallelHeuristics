function solve_TS_LP_RLX(grb_env, data, line_vector::Array{Bool, 1})

    TS = Model()

    @inline function get_lines_subset()
        lines_subset = Vector{Int16}()
        @assert length(line_vector) == length(data.lines)
        for i in 1:length(line_vector)
            if line_vector[i]
                push!(lines_subset, data.lines[i])
            end
        end
        return lines_subset
    end

    lines_subset = get_lines_subset()

    @variable(TS, generation[data.generators] >= 0)
    @variable(TS, theta[data.buses] >= 0)
    @variable(TS, power_flow_var[lines_subset])

    #Set angle at slack node
    #JuMP.fix(theta[data.buses[1]], pi; force = true)

    #Minimal generation costs
    @objective(TS, Min, sum(data.generator_costs[g] * generation[g] for g in data.generators))

    #Current law
    alpha = @constraint(TS, market_clearing[n = data.buses],
    sum(generation[g] for g in data.generators_at_bus[n]) + sum(power_flow_var[l] for l in data.lines_start_at_bus[n] if l in Set(lines_subset)) - sum(power_flow_var[l] for l in data.lines_end_at_bus[n] if l in Set(lines_subset)) == data.bus_demand[n])

    #Voltage law
    beta = @constraint(TS, voltage_1[l = lines_subset],
    (data.base_mva / data.line_reactance[l]) * (theta[data.line_start[l]] - theta[data.line_end[l]]) == power_flow_var[l])

    #Capacity constraint
    gamma = @constraint(TS, production_capacity[g = data.generators], generation[g] <= data.generator_capacity[g])

    #Angle limits
    eta = @constraint(TS, theta_limit_1[n = data.buses], theta[n] <= pi)

    #Line limit
    @constraint(TS, power_flow_limit_1[l in lines_subset], power_flow_var[l] <= data.line_capacity[l])
    @constraint(TS, power_flow_limit_2[l in lines_subset], power_flow_var[l] >= -data.line_capacity[l])

    t = Base.time()
    optimize!(TS, with_optimizer(Gurobi.Optimizer, grb_env, Threads = 1, OutputFlag = 0))
    time = Base.time() - t
    status = termination_status(TS)
    objective = 0.0
    solution = [0.0]

    if status == MOI.TerminationStatusCode(1)

        @inline function expand(arr::Array{Float64, 1}, idctr::Array{Bool, 1})
            output = Vector{Float64}()
            ctr = 1
            for i in 1:length(idctr)
                if idctr[ctr]
                    push!(output, arr[ctr])
                    ctr += 1
                else
                    push!(output, 0.0)
                end
            end
            return output
        end

        objective = objective_value(TS)

        #grb_model = backend(TS).optimizer.model.inner
        #nv = Gurobi.get_intattr(grb_model, "NumVars")
        @inline function convertArray(type::Type, array::T where T <: Array{Bool, 1})

            out = Vector{type}()
            for i in 1:length(array)
                if array[i]
                    push!(out, 1.0)
                else
                    push!(out, 0.0)
                end
            end
            return out
        end

        @inline function get_solution_vector()
            output = [value.(generation).data...,
                      value.(theta).data...,
                      expand(value.(power_flow_var).data, line_vector)...,
                      convertArray(Float64, line_vector)...]
            return output
        end
    end

    return time, status, objective, get_solution_vector() #Gurobi.get_dblattrarray(grb_model, "X", 1, nv)
end

#=
using JuMP
using Gurobi

m = Model()

@variable(m, x >= 1)

@objective(m, Min, x)

optimize!(m, with_optimizer(Gurobi.Optimizer, Threads = 1))
=#
