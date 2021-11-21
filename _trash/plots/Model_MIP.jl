function solve_TS_MIP(data; heuristic = false, threads = 4, time_limit = 20)

    send_counter = 0
    env_ts = Gurobi.Env()
    #logger = Logger(0, Vector{Float64}(), Vector{Float64}(), Vector{Float64}(), Vector{Float64}())

    @inline function restrictiveM()
        out = Dict{Int64, Float64}()
        for i in 1:length(data.lines)
            l = data.lines[i]
            push!(out, l => (1 / data.line_reactance[l]) * abs(THETAMAX - THETAMIN))


        end
        return out
    end

    M = restrictiveM()

    TS = Model(with_optimizer(Gurobi.Optimizer, env_ts, TimeLimit = time_limit, Heuristics = 0.0, Threads = threads,  OutputFlag = 1))

    @variable(TS, generation[data.generators] >= 0)
    @variable(TS, theta[data.buses])
    @variable(TS, power_flow[data.lines])
    @variable(TS, switched[data.lines], Bin)

    #Minimal generation costs
    @objective(TS, Min, sum(data.generator_costs[g] * generation[g] * data.base_mva for g in data.generators))

    #Current law
    @constraint(TS, market_clearing[n = data.buses],
    sum(generation[g] for g in data.generators_at_bus[n]) + sum(power_flow[l] for l in data.lines_start_at_bus[n]) - sum(power_flow[l] for l in data.lines_end_at_bus[n]) == data.bus_demand[n] / data.base_mva)

    #Voltage law
    @constraint(TS, voltage_1[l = data.lines],
    (1 / data.line_reactance[l]) * (theta[data.line_start[l]] - theta[data.line_end[l]]) + (1 - switched[l]) * M[l] >= power_flow[l])

    @constraint(TS, voltage_2[l = data.lines],
    (1 / data.line_reactance[l]) * (theta[data.line_start[l]] - theta[data.line_end[l]]) <= power_flow[l] + (1 - switched[l]) * M[l])

    #Capacity constraint
    @constraint(TS, production_capacity[g = data.generators], generation[g] <= data.generator_capacity[g] / data.base_mva)

    #Angle limits
    @constraint(TS, theta_limit1[n = data.buses], theta[n] <= THETAMAX)
    @constraint(TS, theta_limit2[n = data.buses], theta[n] >= THETAMIN)

    #Line limit
    @constraint(TS, power_flow_limit_1[l in data.lines], power_flow[l] <= (data.line_capacity[l] / data.base_mva) * switched[l])
    @constraint(TS, power_flow_limit_2[l in data.lines], power_flow[l] >= (-data.line_capacity[l] / data.base_mva) * switched[l])

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

        # Saving progress
        #----------------
        if where == convert(Cint, Gurobi.CB_MIPNODE)
            inc = Gurobi.cbget_mipnode_objbst(cbdata, where)
            lb = Gurobi.cbget_mipnode_objbnd(cbdata, where)
            time = Gurobi.cbget_runtime(cbdata, where)
            src = 0.0
            save(logger, [inc, lb, time, src])
        end

        if where == convert(Cint, Gurobi.CB_MIPNODE)

            #TODO: Rewrite for multiple worker threads

            # Send current incumbent solution
            #--------------------------------
            if where == convert(Cint, Gurobi.CB_MIPNODE)
                send_counter += 1
                if send_counter == 4
                    send_counter = 0
                    if Gurobi.cbget_mip_solcnt(cbdata, where) >= 0
                        cb_incumbent = Gurobi.cbget_mipsol_sol(cbdata, where)
                        cb_objective = Gurobi.cbget_mipsol_obj(cbdata, where)
                        if typeof(cb_incumbent) == Array{Float64, 1} && typeof(cb_objective) == Float64
                            MPI.isend([cb_objective, cb_incumbent...], 1, MSG_INCUMBENT, cw)
                        end
                    end
                end
            end

            status, message = MPI.irecv(1, MSG_SOLUTIONS, cw)

            amnt = 0
            min_obj = 0

            if status && message != nothing && typeof(message) != Bool

                for i in 1:length(message[2])
                    Gurobi.cbsolution(cbdata, message[1][i])
                    inc = message[2][i]
                    lb = Gurobi.cbget_mipnode_objbnd(cbdata, where)
                    time = Gurobi.cbget_runtime(cbdata, where)
                    src = 1.0
                    save(logger, [inc, lb, time, src])
                    min_obj = i
                    amnt = i
                end

                println("----------------------------------------------------------------------------")
                println("[INFO] Message received from heuristic on rank ", 1 ,".")
                println("[INFO] Solution(s) Found: ", amnt, ", Solution(s) Passed: ", min_obj)
                println("----------------------------------------------------------------------------")
                marker = " <"
                for i in 1:length(message[2])
                    #i == min_obj ? marker = " <" : marker = ""
                    println("SolNr ",i,", ObjVal: ", message[2][i], " CT: ", message[3][i], marker)
                end
                println("----------------------------------------------------------------------------")
                recent_update = true
            end
        end
    end

    MOIU.attach_optimizer(TS)

    #if heuristic && false
        #Gurobi.set_callback_func!(backend(TS).optimizer.model.inner, pscc_callback_rcv)
    #end

    grb_model = backend(TS).optimizer.model.inner

    generation_idx = [TS.moi_backend.model_to_optimizer_map[index(generation[1])].value,
                      TS.moi_backend.model_to_optimizer_map[index(generation[length(data.generators)])].value]
    theta_idx = [TS.moi_backend.model_to_optimizer_map[index(theta[data.buses[1]])].value,
                 TS.moi_backend.model_to_optimizer_map[index(theta[length(data.buses)])].value]
    power_flow_idx = [TS.moi_backend.model_to_optimizer_map[index(power_flow[1])].value,
                      TS.moi_backend.model_to_optimizer_map[index(power_flow[length(data.lines)])].value]
    switched_idx = [TS.moi_backend.model_to_optimizer_map[index(switched[1])].value,
                    TS.moi_backend.model_to_optimizer_map[index(switched[length(data.lines)])].value]

    println("Variable Indexes:")
    println("generation:", generation_idx)
    println("theta:     ", theta_idx)
    println("power_flow:", power_flow_idx)
    println("switched:  ", switched_idx)

    update_model!(grb_model)

    #=
    for i in 1:length(data.lines)
        grb_idx = TS.moi_backend.model_to_optimizer_map[index(switched[i])].value
        Gurobi.set_dblattrelement!(grb_model, "Start", grb_idx, 1.0)
        #print(grb_idx," ")
    end=#

    optimize!(TS)

    #print(Gurobi.get_dblattrarray(grb_model,"X", 1, num_vars(grb_model)))

    t = Gurobi.get_runtime(grb_model)
    objective = objective_value(TS)
    solution = [0.0]

    solution = [value.(generation).data...,
                value.(theta).data...,
                value.(power_flow).data...,
                value.(switched).data...]

    #print(solution)

    return t, objective, solution
end
