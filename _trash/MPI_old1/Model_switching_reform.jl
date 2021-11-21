function solve_TS_MILP_REF(data; heuristic = false, threads = 4, time_limit = 20)

    recent_update = false

    # print(data.lines,"\n")
    # print(data.generators,"\n")
    # print(data.line_reactance,"\n")
    #--------------------------------

    # Parameters
    #-----------

    @inline function conservativeM()
        M = 0
        for i in 1:length(data.lines)
            l = data.lines[i]
            M += data.line_capacity[l] / data.line_reactance[l]
        end
        return M
    end

    M = 10000 #conservativeM()
    println("[INFO] BIG M equals to ", M)

    TS = Model(with_optimizer(Gurobi.Optimizer, TimeLimit = time_limit, Threads = threads))

    @variable(TS, generation[data.generators] >= 0)
    @variable(TS, theta[data.lines])
    @variable(TS, power_flow_var[data.lines])
    @variable(TS, switched[data.lines], Bin)

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
    @constraint(TS, voltage_1[l = data.lines],
    (1 / data.line_reactance[l]) * theta[l] + (1 - switched[l]) * M >= power_flow_var[l])

    @constraint(TS, voltage_2[l = data.lines],
    (1 / data.line_reactance[l]) * theta[l] <= power_flow_var[l] + (1 - switched[l]) * M)


    #Capacity constraint
    @constraint(TS, production_capacity[g = data.generators], generation[g] <= data.generator_capacity[g])

    #Angle limits
    @constraint(TS, theta_limit_1[l = data.lines], theta[l] <= 30)
    @constraint(TS, theta_limit_2[l = data.lines], theta[l] >= -30)

    #Line limit
    cref = @constraint(TS, power_flow_limit_1[l in data.lines], power_flow_var[l] <= data.line_capacity[l] * switched[l])
    @constraint(TS, power_flow_limit_2[l in data.lines], power_flow_var[l] >= -data.line_capacity[l] * switched[l])

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

        # READS VARIABLES AFTER PRESOLVE AND INJECTS INITIAL GUESS
        #---------------------------------------------------------

        if where == convert(Cint, Gurobi.CB_MIPNODE)

            status, message = MPI.irecv(1, MSG_SOLUTIONS, cw)

            if recent_update
                if Gurobi.cbget_mip_solcnt(cbdata, where) >= 1
                    incumbent = Gurobi.cbget_mipsol_sol(cbdata, where)
                    MPI.isend(incumbent, 1, MSG_INCUMBENT, cw)
                    recent_update = false
                end
            end

            amnt = 0
            min_obj = 0

            if status && message != nothing && typeof(message) != Bool

                for i in 1:length(message[2])
                    Gurobi.cbsolution(cbdata, message[1][i])
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

    t = time()
    MOIU.attach_optimizer(TS)

    if heuristic && false
        Gurobi.set_callback_func!(backend(TS).optimizer.model.inner, pscc_callback_rcv)
    end

    grb_model = backend(TS).optimizer.model.inner
    optimize!(TS)

    objective = 0.0
    solution = [0.0]

    solution = [value.(generation).data...,
                value.(theta).data...,
                value.(power_flow_var).data...,
                value.(switched).data...]

    #print(solution)

    return solution
end
