function solve_TS_MILP_DEC(grb_env, data, line_indicators::Array{Bool, 1}, constraint_indicators::Array{Bool, 1}; heuristic = false, threads = 1, time_limit = 5)

    # print(data.lines,"\n")
    # print(data.generators,"\n")
    # print(data.line_reactance,"\n")
    #--------------------------------

    # Parameters
    #-----------
    #=
    @inline function conservativeM()
        M = 0
        for i in 1:length(data.lines)
            l = data.lines[i]
            M += data.line_capacity[l] / data.line_reactance[l]
        end
        return M
    end =#

    @inline function restrictiveM()
        out = Dict{Int64, Float64}()
        for i in 1:length(data.lines)
            l = data.lines[i]
            push!(out, l => data.base_mva / data.line_reactance[l] * (THETAMAX - THETAMIN) * 2)


        end
        return out
    end

    M = restrictiveM()

    TS = Model(with_optimizer(Gurobi.Optimizer, grb_env, TimeLimit = time_limit, Threads = threads, OutputFlag = 0, PoolSolutions = 3))

    @variable(TS, generation[data.generators] >= 0)
    @variable(TS, theta[data.buses])
    @variable(TS, power_flow[data.lines])
    @variable(TS, switched[l = data.lines; !constraint_indicators[l]], Bin)


    #Minimal generation costs
    @objective(TS, Min, sum(data.generator_costs[g] * generation[g] * data.base_mva for g in data.generators))

    #Current law
    @constraint(TS, market_clearing[n = data.buses],
    sum(generation[g] for g in data.generators_at_bus[n]) + sum(power_flow[l] for l in data.lines_start_at_bus[n]) - sum(power_flow[l] for l in data.lines_end_at_bus[n]) == data.bus_demand[n] / data.base_mva)

    #Voltage law
    @constraint(TS, voltage_1[l = data.lines; !constraint_indicators[l]],
    (1 / data.line_reactance[l]) * (theta[data.line_start[l]] - theta[data.line_end[l]]) + (1 - switched[l]) * M[l] >= power_flow[l])

    @constraint(TS, voltage_2[l = data.lines; !constraint_indicators[l]],
    (1 / data.line_reactance[l]) * (theta[data.line_start[l]] - theta[data.line_end[l]]) <= power_flow[l] + (1 - switched[l]) * M[l])

    @constraint(TS, voltage[l = data.lines; line_indicators[l] && constraint_indicators[l]],
    (1 / data.line_reactance[l]) * (theta[data.line_start[l]] - theta[data.line_end[l]]) == power_flow[l])

    #Capacity constraint
    @constraint(TS, production_capacity[g = data.generators], generation[g] <= data.generator_capacity[g] / data.base_mva)

    #Angle limits
    @constraint(TS, theta_limit1[n = data.buses], theta[n] <= THETAMAX)
    @constraint(TS, theta_limit2[n = data.buses], theta[n] >= THETAMIN)

    #Line limit
    @constraint(TS, power_flow_limit_11[l = data.lines; !constraint_indicators[l]], power_flow[l] <= data.line_capacity[l] / data.base_mva * switched[l])
    @constraint(TS, power_flow_limit_12[l = data.lines; !constraint_indicators[l]], power_flow[l] >= -data.line_capacity[l] / data.base_mva * switched[l])

    @constraint(TS, power_flow_limit_21[l = data.lines; line_indicators[l] && constraint_indicators[l]], power_flow[l] <= data.line_capacity[l] / data.base_mva)
    @constraint(TS, power_flow_limit_22[l = data.lines; line_indicators[l] && constraint_indicators[l]], power_flow[l] >= -data.line_capacity[l] / data.base_mva)

    MOIU.attach_optimizer(TS)
    optimize!(TS)
    grb_model = backend(TS).optimizer.model.inner
    time = Gurobi.get_runtime(grb_model)

    @inline function recover_sols(model::JuMP.Model,
                              line_indicators::Array{Bool, 1},
                              constraint_indicators::Array{Bool, 1})

        @assert length(line_indicators) == length(constraint_indicators)
        @assert length(line_indicators) == length(data.lines)

        grb_model = backend(model).optimizer.model.inner
        num_sols = Gurobi.get_intattr(grb_model, "SolCount")
        solutions = Vector{Vector{Float64}}()
        objectives = Vector{Float64}()
        #=num_lines = length(line_indicators)
        num_vars = Gurobi.get_intattr(grb_model, "NumVars")

        vrefs = Vector{VariableRef}()
        vidxs = Vector{Int64}()

        for (i, value) in enumerate(model[:switched])
            push!(vrefs, value)
            push!(vidxs, vrefs[i].index.value)
        end

        root_idx = minimum(vidxs) - 1=#

        @inline function recover_vector(attr::String)

            output = Vector{Float64}()
            for i in 1:length(data.generators)
                push!(output, Gurobi.get_dblattrelement(grb_model, attr, model.moi_backend.model_to_optimizer_map[index(generation[data.generators[i]])].value))
            end
            for i in 1:length(data.lines)
                if constraint_indicators[i]
                    if line_indicators[i]
                        push!(output, 1.0)
                    else
                        push!(output, 0.0)
                    end
                else
                    push!(output, round(Gurobi.get_dblattrelement(grb_model, attr, model.moi_backend.model_to_optimizer_map[index(switched[data.lines[i]])].value)))
                end
            end
            for i in 1:length(data.buses)
                push!(output, Gurobi.get_dblattrelement(grb_model, attr, model.moi_backend.model_to_optimizer_map[index(theta[data.buses[i]])].value))
            end
            for i in 1:length(data.lines)
                push!(output, Gurobi.get_dblattrelement(grb_model, attr, model.moi_backend.model_to_optimizer_map[index(power_flow[data.lines[i]])].value))
            end

            return output
        end

        # Recover Optimal Solution
        #-------------------------
        push!(solutions, recover_vector("X"))
        push!(objectives, objective_value(model))

        # Recover Pool Solutions
        #-----------------------
        for i in 1:(num_sols - 1)
            Gurobi.set_int_param!(grb_model, "SolutionNumber", i)
            push!(solutions, recover_vector("Xn"))
            push!(objectives, Gurobi.get_dblattr(grb_model, "PoolObjVal"))
        end

        return objectives, solutions
    end

    status = termination_status(TS)
    has_vals = has_values(TS)
    objectives = [0.0]
    solutions = [[0.0]]

    if status == MOI.TerminationStatusCode(1) || has_vals

        objectives, solutions = recover_sols(TS, line_indicators, constraint_indicators)

    end

    return time, status, has_vals, objectives, solutions

end
