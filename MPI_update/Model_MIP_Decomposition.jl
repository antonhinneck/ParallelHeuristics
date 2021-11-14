function solve_TS_MIP_Deco(grb_env, data, line_indicators::Array{Bool, 1}, constraint_indicators::Array{Bool, 1}, optimizer_terminated, mipstart::Array{Bool,1}; heuristic = false, threads = 1, time_limit = 5, uplink = true)

    switchable = Vector{Int64}()
    sreq = nothing
    last_root_recv = 0.0
    probing_frequency = 10.0
    obj_lower_than_root = 0.0
    root_inc = nothing

    @inline function restrictiveM()
        out = Dict{Int64, Float64}()
        for i in 1:length(data.lines)
            l = data.lines[i]
            if !constraint_indicators[i]
                push!(switchable, l)
            end
            push!(out, l => 1 / data.line_reactance[l] * abs(THETAMAX - THETAMIN))
        end
        return out
    end

    M = restrictiveM()

    # TS = Model(with_optimizer(Gurobi.Optimizer, grb_env, Threads = threads, OutputFlag = 1, Heuristics = 0.25, PoolSolutions = 3, TimeLimit = time_limit))
    TS = Model(optimizer_with_attributes(() -> Gurobi.Optimizer(grb_env), "TimeLimit" => time_limit, "Threads" => threads,  "OutputFlag" => 1, "Heuristics" => 0.3, "PoolSolutions" => 3))

    @variable(TS, generation[data.generators] >= 0)
    @variable(TS, theta[data.buses])
    @variable(TS, power_flow[l = data.lines])
    @variable(TS, switched[l = data.lines; !constraint_indicators[l]], Bin)


    #Minimal generation costs
    @objective(TS, Min, sum(data.generator_costs[g] * generation[g] * data.base_mva for g in data.generators))

    #Current law
    @constraint(TS, market_clearing[n = data.buses],
    sum(generation[g] for g in data.generators_at_bus[n]) + sum(power_flow[l] for l in data.lines_start_at_bus[n] if line_indicators[l] || !constraint_indicators[l]) - sum(power_flow[l] for l in data.lines_end_at_bus[n] if line_indicators[l] || !constraint_indicators[l]) == data.bus_demand[n] / data.base_mva)

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

    @constraint(TS, power_flow_limit[l = data.lines; !line_indicators[l] && constraint_indicators[l]], power_flow[l] == 0.0)

    @inline function pscc_callback_rcv(cbdata::CallbackData, where::Cint)
        # CALLBACK FUNCTION - HOOKS INTO GUROBI
        # PSCC2020 CONTRIBUTION
        #----------------------
        # SOLVER STATES:
        #---------------
            #const CB_POLLING = 0
            #const CB_PRESOLVE = 1
            #const CB_SIMPLEX = 2
            #const CB_MIP = 3
            #const CB_MIPSOL = 4
            #const CB_MIPNODE = 5
            #const CB_MESSAGE = 6
            #const CB_BARRIER = 7

        if where == Cint(Gurobi.CB_MIPNODE)
            rt = Gurobi.cbget_runtime(cbdata, where)
            diff = rt - last_root_recv
            available, stats = MPI.Iprobe(ROOT, MSG_ROOT_INC, cw)
            if available
                status, message = MPI.irecv(ROOT, MSG_ROOT_INC, cw)
                root_inc = message
                #println("OBJ: ", root_incumbent[1])
            end

            if diff > probing_frequency
                cobj = Gurobi.cbget_mipnode_objbst(cbdata, where)
                if root_inc != nothing
                    if cobj > root_inc[1]
                        obj_lower_than_root += probing_frequency
                    else
                        obj_lower_than_root = 0.0
                        println("equal")
                    end
                end

                if obj_lower_than_root > 20 #obj_lower_than_root > 60.0
                    Gurobi.terminate(grb_model)
                end
                last_root_recv = rt
            end
        end

        if where == Cint(Gurobi.CB_MIPSOL)

            cobj = Gurobi.cbget_mipsol_objbst(cbdata, where)
            if root_inc != nothing
                if cobj < root_inc[1]
                    obj_lower_than_root = 0.0
                end
            end

            # Full Vector
            solution = Gurobi.cbget_mipsol_sol(cbdata, where)

            generation_res = Vector{Float64}()
            theta_res = Vector{Float64}()
            power_flow_res = Vector{Float64}()
            switched_res = Vector{Float64}()

            for i in 1:length(data.generators)
                name = string("generation[",i,"]")
                var_ref = JuMP.variable_by_name(TS, name)
                idx = TS.moi_backend.model_to_optimizer_map[index(var_ref)].value
                push!(generation_res, solution[idx])
            end

            for i in 1:length(data.buses)
                name = string("theta[",data.buses[i],"]")
                var_ref = JuMP.variable_by_name(TS, name)
                idx = TS.moi_backend.model_to_optimizer_map[index(var_ref)].value
                push!(theta_res, solution[idx])
            end

            for i in 1:length(data.lines)
                name = string("power_flow[",i,"]")
                var_ref = JuMP.variable_by_name(TS, name)
                idx = TS.moi_backend.model_to_optimizer_map[index(var_ref)].value
                push!(power_flow_res, solution[idx])
            end

            for i in 1:length(data.lines)
                if constraint_indicators[i]
                    if line_indicators[i]
                        push!(switched_res, 1.0)
                    else
                        push!(switched_res, 0.0)
                    end
                else
                    name = string("switched[",i,"]")
                    var_ref = JuMP.variable_by_name(TS, name)
                    idx = TS.moi_backend.model_to_optimizer_map[index(var_ref)].value
                    push!(switched_res, abs(round(solution[idx])))
                end
            end

            out_sol = Vector{Vector{Float64}}()
            out_obj = Vector{Float64}()
            push!(out_sol, [generation_res...,switched_res...,theta_res...,power_flow_res...])
            push!(out_obj, Gurobi.cbget_mipsol_objbst(cbdata, where))
            time = Gurobi.cbget_runtime(cbdata, where)
            #println(out_sol[1])
            sreq = MPI.isend([out_sol, out_obj, time], ROOT, MSG_SOLUTIONS, cw)
            (inds, stats) = MPI.Waitsome!([sreq])
            # if sreq != nothing
            #     (done, status) = MPI.Test!(sreq)
            #     if done
            #         sreq = MPI.isend([out_sol, out_obj, time], ROOT, MSG_SOLUTIONS, cw)
            #         (inds, stats) = MPI.Waitsome!([sreq])
            #     end
            # else
            #     sreq = MPI.isend([out_sol, out_obj, time], ROOT, MSG_SOLUTIONS, cw)
            # end
        end
    end

    MOIU.attach_optimizer(TS)
    grb_model = backend(TS).optimizer.model.inner
    Gurobi.update_model!(grb_model)
    if uplink
        Gurobi.set_callback_func!(backend(TS).optimizer.model.inner, pscc_callback_rcv)
    end
    for i in 1:length(data.lines)
        if !constraint_indicators[i]
            grb_idx = TS.moi_backend.model_to_optimizer_map[index(switched[i])].value
            if mipstart[i]
                Gurobi.set_dblattrelement!(grb_model, "Start", grb_idx, 1.0)
            else
                Gurobi.set_dblattrelement!(grb_model, "Start", grb_idx, 0.0)
            end
        end
    end
    optimize!(TS)
    ct = Gurobi.get_runtime(grb_model)

    # switched_res = Vector{Float64}()
    #
    # for i in 1:length(data.lines)
    #     if constraint_indicators[i]
    #         if line_indicators[i]
    #             push!(switched_res, 1.0)
    #         else
    #             push!(switched_res, 0.0)
    #         end
    #     else
    #         name = string("switched[",i,"]")
    #         var_ref = JuMP.variable_by_name(TS, name)
    #         idx = TS.moi_backend.model_to_optimizer_map[index(var_ref)].value
    #         push!(switched_res, abs(round(value.(switched).data[idx])))
    #     end
    # end
    #
    # time = Gurobi.cbget_runtime(cbdata, where)
    #
    # solution = [value.(generation).data...,switched_res...,value.(theta).data...,value.(power_flow).data...]
    # objective = objective_value(TS)
    #
    # sreq = MPI.isend([objective, solution], ROOT, MSG_SOLUTIONS, cw)
    # (inds, stats) = MPI.Waitsome!([sreq])

    #=@inline function recover_sols(model::JuMP.Model,
                              line_indicators::Array{Bool, 1},
                              constraint_indicators::Array{Bool, 1})

        @assert length(line_indicators) == length(constraint_indicators)
        @assert length(line_indicators) == length(data.lines)

        grb_model = backend(model).optimizer.model.inner
        num_sols = Gurobi.get_intattr(grb_model, "SolCount")
        solutions = Vector{Vector{Float64}}()
        objectives = Vector{Float64}()
        num_lines = length(line_indicators)
        num_vars = Gurobi.get_intattr(grb_model, "NumVars")

        vrefs = Vector{VariableRef}()
        vidxs = Vector{Int64}()

        for (i, value) in enumerate(model[:switched])
            push!(vrefs, value)
            push!(vidxs, vrefs[i].index.value)
        end

        root_idx = minimum(vidxs) - 1=#

        #=@inline function recover_vector(attr::String)

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
    end=#

    status = termination_status(TS)
    has_vals = has_values(TS)
    #objectives = [0.0]
    #solutions = [[0.0]]

    if status == MOI.TerminationStatusCode(1) || has_vals

        for i in switchable
            if round(value(switched[i])) == 1.0
                mipstart[i] = true
            else
                mipstart[i] = false
            end
        end
        #objectives, solutions = recover_sols(TS, line_indicators, constraint_indicators)
    end

    return root_inc, termination_status(TS)
end
