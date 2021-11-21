function solve_TS_MIP_Deco(grb_env, data, Iea::Array{Bool, 1}, Ies::Array{Bool, 1}, optimizer_terminated, mipstart::Array{Bool,1}; heuristic = false, threads = 1, time_limit = 5, uplink = true, outputflag = 0)

    switchable = Vector{Int64}()
    sreq = nothing
    last_root_recv = 0.0
    probing_frequency = 10.0
    obj_lower_than_root = 0.0
    root_inc = nothing
    nv = length(data.generators) + length(data.buses) + length(data.lines) + sum(Ies)

    @inline function restrictiveM()
        out = Dict{Int64, Float64}()
        for i in 1:length(data.lines)
            l = data.lines[i]
            if Ies[i]
                push!(switchable, l)
            end
            push!(out, l => ( 2.0 * data.base_mva / data.line_x[l]) * abs(THETAMAX - THETAMIN))
        end
        return out
    end

    M = restrictiveM()

    # TS = Model(with_optimizer(Gurobi.Optimizer, grb_env, Threads = threads, OutputFlag = 1, Heuristics = 0.25, PoolSolutions = 3, TimeLimit = time_limit))
    TS = Model(optimizer_with_attributes(() -> Gurobi.Optimizer(grb_env), "TimeLimit" => time_limit, "Threads" => threads,  "OutputFlag" => outputflag, "Heuristics" => 0.3, "PoolSolutions" => 3))

    @variable(TS, p[data.generators] >= 0)
    @variable(TS, v[data.buses])
    @variable(TS, f[l = data.lines])
    @variable(TS, z[l = data.lines; Ies[l]], Bin)

    #Minimal generation costs
    @objective(TS, Min, sum(data.generator_c1[g] * p[g] for g in data.generators))

    #Current law
    @constraint(TS, market_clearing[n = data.buses],
    sum(p[g] for g in data.generators_at_bus[n]) + sum(f[l] for l in data.lines_start_at_bus[n] if Iea[l] || Ies[l]) - sum(f[l] for l in data.lines_end_at_bus[n] if Iea[l] || Ies[l]) == data.bus_Pd[n])

    #Voltage law
    @constraint(TS, voltage_1[l = data.lines; Ies[l]],
    (data.base_mva / data.line_x[l]) * (v[data.bus_id[data.line_start[l]]] - v[data.bus_id[data.line_end[l]]]) + (1 - z[l]) * M[l] >= f[l])

    @constraint(TS, voltage_2[l = data.lines; Ies[l]],
    (data.base_mva / data.line_x[l]) * (v[data.bus_id[data.line_start[l]]] - v[data.bus_id[data.line_end[l]]]) <= f[l] + (1 - z[l]) * M[l])

    @constraint(TS, voltage[l = data.lines; Iea[l] && !Ies[l]],
    (data.base_mva / data.line_x[l]) * (v[data.bus_id[data.line_start[l]]] - v[data.bus_id[data.line_end[l]]]) == f[l])

    #Capacity constraint
    @constraint(TS, production_capacity1[g = data.generators], p[g] <= data.generator_Pmax[g])
    @constraint(TS, production_capacity2[g = data.generators], p[g] >= data.generator_Pmin[g])

    #Angle limits
    @constraint(TS, theta_limit1[n = data.buses], v[n] <= THETAMAX)
    @constraint(TS, theta_limit2[n = data.buses], v[n] >= THETAMIN)

    #Line limit
    @constraint(TS, power_flow_limit_11[l = data.lines; Ies[l]], f[l] <= data.line_capacity[l] * z[l])
    @constraint(TS, power_flow_limit_12[l = data.lines; Ies[l]], f[l] >= -data.line_capacity[l] * z[l])

    @constraint(TS, power_flow_limit_21[l = data.lines; Iea[l] && !Ies[l]], f[l] <= data.line_capacity[l])
    @constraint(TS, power_flow_limit_22[l = data.lines; Iea[l] && !Ies[l]], f[l] >= -data.line_capacity[l])

    @constraint(TS, power_flow_limit[l = data.lines; !Iea[l] && !Ies[l]], f[l] == 0.0)

    @constraint(TS, slack, v[1] == 0.0)

    @inline function callback_rank1(cb_data::CallbackData, cb_where::Cint)
        # CALLBACK FUNCTION - HOOKS INTO GUROBI
        #--------------------------------------
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

        if cb_where == Cint(Gurobi.GRB_CB_MIPNODE)
            rt = Ref{Cdouble}()
            Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_RUNTIME, rt)
            diff = rt[] - last_root_recv
            available, stats = MPI.Iprobe(ROOT, MSG_ROOT_INC, cw)
            if available
                status, message = MPI.irecv(ROOT, MSG_ROOT_INC, cw)
                root_inc = message
                #println("OBJ: ", root_incumbent[1])
            end

            ## Runtime controls
            if diff > probing_frequency
                cobj = Ref{Cdouble}()
                Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_MIPNODE_OBJBST, cobj)
                cbnd = Ref{Cdouble}()
                Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_MIPNODE_OBJBND, cbnd)
                if root_inc != nothing
                    if cobj[] > root_inc[1]
                        obj_lower_than_root += probing_frequency
                    else
                        obj_lower_than_root = 0.0
                    end
                end

                ## Check if the heuristic incumbent is higher than the main rank's incumbent for a sufficient amount of time.
                ## If so, terminate.
                if obj_lower_than_root > 20
                    Gurobi.GRBterminate(cb_data.model)
                end

                ## Check if the heuristic lb >= the main ranks incumbent.
                ## If so, terminate.
                if root_inc != nothing
                    if cbnd > root_inc[1]
                        Gurobi.GRBterminate(cb_data.model)
                    end
                end

                ## Check if optimization on rank 0 terminated.
                ## If so, terminate.
                try
                    if optimizer_terminated[1] == true
                        Gurobi.GRBterminate(cb_data.model)
                    end
                catch e end

                last_root_recv = rt[]
            end
        end

        ## Sending incumbents to rank 0
        if cb_where == Cint(Gurobi.GRB_CB_MIPSOL)

            cobj = Ref{Cdouble}()
            Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_MIPNODE_OBJBST, cobj)
            if root_inc != nothing
                if cobj[] < root_inc[1]
                    obj_lower_than_root = 0.0
                end
            end

            # Full Vector
            solution = Array{Float64, 1}(undef, nv)
            Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_MIPSOL_SOL, solution)

            generation_res = Vector{Float64}()
            theta_res = Vector{Float64}()
            power_flow_res = Vector{Float64}()
            switched_res = Vector{Float64}()

            for i in 1:length(data.generators)
                name = string("p[",i,"]")
                var_ref = JuMP.variable_by_name(TS, name)
                idx = TS.moi_backend.model_to_optimizer_map[index(var_ref)].value
                push!(generation_res, solution[idx])
            end

            for i in 1:length(data.buses)
                name = string("v[",data.buses[i],"]")
                var_ref = JuMP.variable_by_name(TS, name)
                idx = TS.moi_backend.model_to_optimizer_map[index(var_ref)].value
                push!(theta_res, solution[idx])
            end

            for i in 1:length(data.lines)
                name = string("f[",i,"]")
                var_ref = JuMP.variable_by_name(TS, name)
                idx = TS.moi_backend.model_to_optimizer_map[index(var_ref)].value
                push!(power_flow_res, solution[idx])
            end

            for i in 1:length(data.lines)
                if !Ies[i]
                    if Iea[i]
                        push!(switched_res, 1.0)
                    else
                        push!(switched_res, 0.0)
                    end
                else
                    name = string("z[",i,"]")
                    var_ref = JuMP.variable_by_name(TS, name)
                    idx = TS.moi_backend.model_to_optimizer_map[index(var_ref)].value
                    push!(switched_res, abs(round(solution[idx])))
                end
            end

            out_sol = Vector{Vector{Float64}}()
            out_obj = Vector{Float64}()
            push!(out_sol, [generation_res...,switched_res...,theta_res...,power_flow_res...])
            inc = Ref{Cdouble}()
            Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_MIPSOL_OBJBST, inc)
            push!(out_obj, inc[])
            rt = Ref{Cdouble}()
            Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_RUNTIME, rt)
            sreq = MPI.isend([out_sol, out_obj, rt[]], ROOT, MSG_SOLUTIONS, cw)
            (inds, stats) = MPI.Waitsome!([sreq])
        end
    end

    MOIU.attach_optimizer(TS)

    grb_model = backend(TS).optimizer.model

    user_data = _CallbackUserData(
        grb_model,
        (cb_data, cb_where) -> begin
            callback_rank1(cb_data, cb_where)
            return
        end,
    )

    if uplink
        ret = GRBsetcallbackfunc(grb_model, grb_callback, user_data)
    end

    for i in 1:length(data.lines)
        if Ies[i]
            grb_idx = TS.moi_backend.model_to_optimizer_map[index(z[i])].value
            if mipstart[i]
                Gurobi.GRBsetdblattrelement(grb_model, "Start", grb_idx, 1.0)
            else
                Gurobi.GRBsetdblattrelement(grb_model, "Start", grb_idx, 0.0)
            end
        end
    end

    Gurobi.GRBupdatemodel(grb_model)

    GRBoptimize(grb_model)

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
            if round(value(TS[:z][i])) == 1.0
                mipstart[i] = true
            else
                mipstart[i] = false
            end
        end
        #objectives, solutions = recover_sols(TS, line_indicators, constraint_indicators)
    end

    return root_inc, termination_status(TS)
end
