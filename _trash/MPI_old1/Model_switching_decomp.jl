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
        out = Vector{Float64}()
        for i in 1:length(data.lines)
            l = data.lines[i]
            push!(out, data.base_mva / data.line_reactance[l] * (pi - 0))
        end
        out
    end

    M = restrictiveM()#10000 #conservativeM()
    #println("[INFO] BIG M equals to ", M)

    TS = Model(with_optimizer(Gurobi.Optimizer, grb_env, TimeLimit = time_limit, Threads = threads, OutputFlag = 0))

    @variable(TS, generation[data.generators] >= 0)
    @variable(TS, theta[data.buses] >= 0)
    @variable(TS, power_flow_var[data.lines])
    @variable(TS, switched[l = data.lines; !constraint_indicators[l]], Bin)

    #JuMP.fix(switched[1], 1; force = true)
    #JuMP.fix(switched[2], 1; force = true)
    #JuMP.fix(switched[3], 1; force = true)

    #Set angle at slack node
    #JuMP.fix(theta[data.busses[1]], pi; force = true)

    #Minimal generation costs
    @objective(TS, Min, sum(data.generator_costs[g] * generation[g] for g in data.generators))

    #Current law
    @constraint(TS, market_clearing[n = data.buses],
    sum(generation[g] for g in data.generators_at_bus[n]) + sum(power_flow_var[l] for l in data.lines_start_at_bus[n]) - sum(power_flow_var[l] for l in data.lines_end_at_bus[n]) == data.bus_demand[n])

    #Voltage law
    @constraint(TS, voltage_1[l = data.lines; !constraint_indicators[l]],
    (data.base_mva / data.line_reactance[l]) * (theta[data.line_start[l]] - theta[data.line_end[l]]) + (1 - switched[l]) * M[l] >= power_flow_var[l])

    @constraint(TS, voltage_2[l = data.lines; !constraint_indicators[l]],
    (data.base_mva / data.line_reactance[l]) * (theta[data.line_start[l]] - theta[data.line_end[l]]) <= power_flow_var[l] + (1 - switched[l]) * M[l])

    @constraint(TS, voltage[l = data.lines; line_indicators[l] && constraint_indicators[l]],
    (data.base_mva / data.line_reactance[l]) * (theta[data.line_start[l]] - theta[data.line_end[l]]) == power_flow_var[l])

    #Capacity constraint
    @constraint(TS, production_capacity[g = data.generators], generation[g] <= data.generator_capacity[g])

    #Angle limits
    @constraint(TS, theta_limit[n = data.buses], theta[n] <= pi)

    #Line limit
    @constraint(TS, power_flow_limit_11[l = data.lines; !constraint_indicators[l]], power_flow_var[l] <= data.line_capacity[l] * switched[l])
    @constraint(TS, power_flow_limit_12[l = data.lines; !constraint_indicators[l]], power_flow_var[l] >= -data.line_capacity[l] * switched[l])

    @constraint(TS, power_flow_limit_21[l = data.lines; line_indicators[l] && constraint_indicators[l]], power_flow_var[l] <= data.line_capacity[l])
    @constraint(TS, power_flow_limit_22[l = data.lines; line_indicators[l] && constraint_indicators[l]], power_flow_var[l] >= -data.line_capacity[l])

    MOIU.attach_optimizer(TS)
    t = Base.time()
    optimize!(TS)
    time = Base.time() - t

    @inline function recover_sols(model::JuMP.Model,
                              line_indicators::Array{Bool, 1},
                              constraint_indicators::Array{Bool, 1})

        @assert length(line_indicators) == length(constraint_indicators)

        grb_model = backend(model).optimizer.model.inner
        num_lines = length(line_indicators)
        num_vars = Gurobi.get_intattr(grb_model, "NumVars")
        num_sols = Gurobi.get_intattr(grb_model, "SolCount")

        solutions = Array{Vector{Float64}}(undef, num_sols)
        objectives = Vector{Float64}()
        vrefs = Vector{VariableRef}()
        vidxs = Vector{Int64}()

        for (i, value) in enumerate(model[:switched])
            push!(vrefs, value)
            push!(vidxs, vrefs[i].index.value)
        end

        root_idx = minimum(vidxs) - 1

        # Recover Optimal Solution
        #-------------------------

        solutions[1] = Gurobi.get_dblattrarray(grb_model, "X", 1, root_idx)
        push!(objectives, objective_value(TS))
        for i in 1:num_lines
            if constraint_indicators[data.lines[i]]
                push!(solutions[1], line_indicators[i])
            else
                push!(solutions[1], Gurobi.get_dblattrarray(grb_model, "X", model[:switched][data.lines[i]].index.value, 1)[1])
            end
        end

        # Recover Pool Solutions
        #-----------------------
        for i in 1:(num_sols - 1)

            Gurobi.set_int_param!(grb_model, "SolutionNumber", i)
            solutions[i + 1] = Gurobi.get_dblattrarray(grb_model, "Xn", 1, root_idx)
            push!(objectives, Gurobi.get_dblattr(grb_model, "PoolObjVal"))
            # Write solution vector
            #----------------------
            for j in 1:num_lines
                if constraint_indicators[data.lines[i]]
                    push!(solutions[i + 1], line_indicators[i])
                else
                    push!(solutions[i + 1], Gurobi.get_dblattrarray(grb_model, "Xn", model[:switched][data.lines[i]].index.value, 1)[1])
                end
            end
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
