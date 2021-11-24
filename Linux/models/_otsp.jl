function solve_otsp(data; heuristic = false, threads = 4, time_limit = 20, start = false, outputflag = 1, logger_active = false)

    time_probed = false

    cs = 0
    cst = 0.0

    cr = 0
    crt = 0.0

    ts = 0.0

    sreq = nothing
    send_counter = 0
    env_ts = Gurobi.Env()
    logger = Logger(0, Vector{Float64}(), Vector{Float64}(), Vector{Float64}(), Vector{Float64}())
    num_vars = length(data.generators) + length(data.buses) + length(data.lines) + length(data.lines)

    @inline function restrictiveM()
        out = Dict{Int64, Float64}()
        for i in 1:length(data.lines)
            l = data.lines[i]
            push!(out, l => 2.0 * (data.base_mva / data.line_x[l]) * abs(THETAMAX - THETAMIN) + 1.0)
        end
        return out
    end

    M = restrictiveM()

    # TS = Model(with_optimizer(Gurobi.Optimizer, env_ts, TimeLimit = 3600, Thr eads = threads,  OutputFlag = 1))
    m = Model(optimizer_with_attributes(() -> Gurobi.Optimizer(env_ts), "Heuristics" => 0.1, "TimeLimit" => time_limit, "Threads" => threads,  "OutputFlag" => outputflag))

    @variable(m, p[data.generators] >= 0)
    @variable(m, v[data.buses])
    @variable(m, f[data.lines])
    @variable(m, z[data.lines], Bin)

    # Minimal generation costs
    @objective(m, Min, sum(data.generator_c1[g] * p[g] for g in data.generators))

    # Current law
    @constraint(m, nb[n = data.buses],
    sum(p[g] for g in data.generators_at_bus[n]) + sum(f[l] for l in data.lines_start_at_bus[n]) - sum(f[l] for l in data.lines_end_at_bus[n]) == data.bus_Pd[n])

    # Voltage law
    @constraint(m, voltage_1[l = data.lines],
    (data.base_mva / data.line_x[l]) * (v[data.bus_id[data.line_start[l]]] - v[data.bus_id[data.line_end[l]]]) + (1 - z[l]) * M[l] >= f[l])
    
    @constraint(m, voltage_2[l = data.lines],
    (data.base_mva / data.line_x[l]) * (v[data.bus_id[data.line_start[l]]] - v[data.bus_id[data.line_end[l]]]) <= f[l] + (1 - z[l]) * M[l])

    # Capacity constraint
    @constraint(m, production_capacity1[g = data.generators], p[g] <= data.generator_Pmax[g])
    #@constraint(m, production_capacity2[g = data.generators], p[g] >= 0)#data.generator_Pmin[g])

    # Angle limits
    @constraint(m, theta_limit1[n = data.buses], v[n] <= THETAMAX)
    @constraint(m, theta_limit2[n = data.buses], v[n] >= THETAMIN)

    # Line limit
    @constraint(m, fl1[l in data.lines], f[l] <=  data.line_capacity[l] * z[l])
    @constraint(m, fl2[l in data.lines], f[l] >= -data.line_capacity[l] * z[l])

    # JuMP.fix(v[1], 0.0, force = true)

    @inline function get_switching_status!(switching_status, solution)
        for i in 1:length(data.lines)
            name = string("z[",i,"]")
            var_ref = JuMP.variable_by_name(m, name)
            idx = m.moi_backend.model_to_optimizer_map[index(var_ref)].value
            push!(switching_status, Bool(Int64(abs(round(solution[idx])))))
        end
    end

    @inline function callback_logger(cb_data::CallbackData, cb_where::Cint)

        # Saving progress
        #----------------
        if cb_where == convert(Cint, Gurobi.GRB_CB_MIPNODE)

            if Cint(cb_where) == Gurobi.GRB_CB_MIPNODE
                inc = Ref{Cdouble}()
                lb = Ref{Cdouble}()
                Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_MIPNODE_OBJBST, inc)
                Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_MIPNODE_OBJBND, lb)
                time = Ref{Cdouble}()
                Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_RUNTIME, time)
                src = 0.0
                save(logger, [inc[], lb[], time[], src])
            end
        end
    end

    @inline function callback_rank0(cb_data::CallbackData, cb_where::Cint)
        # CALLBACK FUNCTION - HOOKS INTO GUROBI
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
        rcv = false
        if cb_where == convert(Cint, Gurobi.GRB_CB_MIPNODE)

            if !time_probed
                println(string("Presolve completed: ", Base.time() - t))
                time_probed = true
                ts = Base.time()
            end

            if Cint(cb_where) == Gurobi.GRB_CB_MIPNODE
                inc = Ref{Cdouble}()
                lb = Ref{Cdouble}()
                Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_MIPNODE_OBJBST, inc)
                Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_MIPNODE_OBJBND, lb)
                time = Ref{Cdouble}()
                Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_RUNTIME, time)
                src = 0.0
                save(logger, [inc[], lb[], time[], src])
            end
        end

        # if cb_where == Cint(Gurobi.GRB_CB_MIPSOL)
        #     inc_sol = Array{Float64, 1}(undef, num_variables(m))
        #     Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_MIPSOL_SOL, inc_sol)
        #     println(inc_sol)
        # end

        # # SEND
        # if cb_where == Cint(Gurobi.GRB_CB_MIPSOL)

        #     switching_status = Vector{Int64}()
        #     inc_sol = Array{Float64, 1}()
        #     Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_MIPSOL_SOL, inc_sol)
        #     get_switching_status!(switching_status, inc_sol)

        #     inc = Ref{Cdouble}()
        #     Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_MIPSOL_OBJBST, inc)
        #     # incumbent_obj = Gurobi.cbget_mipsol_objbst(cbdata, where)

        #     cs += 1
        #     t = Base.time()
        #     if sreq != nothing
        #         (done, status) = MPI.Test!(sreq)
        #         if done
        #             sreq = MPI.isend([incumbent_obj, switching_status], HRSTC, MSG_ROOT_INC, cw)
        #         end
        #     else
        #         sreq = MPI.isend([incumbent_obj, switching_status], HRSTC, MSG_ROOT_INC, cw)
        #     end
        #     cst += Base.time() - t
        # end

        ## Broadcast incumbent
        ## TODO: Rewrite for multiple worker threads (make HRSTC const array)
        if cb_where == convert(Cint, Gurobi.GRB_CB_MIPSOL)
            # Send current incumbent solution
            #--------------------------------
            solcnt = Ref{Cint}()
            Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_MIPSOL_SOLCNT, solcnt) 

            if solcnt[] >= 0
                cinc = Array{Float64}(undef, num_vars)
                Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_MIPSOL_SOL, cinc)
                cobj = Ref{Cdouble}()
                Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_MIPSOL_OBJBST, cobj)
                cbnd = Ref{Cdouble}()
                Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_MIPSOL_OBJBND, cbnd)
                
                if typeof(cinc) == Array{Float64, 1} && typeof(cobj[]) == Float64
                    for hrstc_rank in 1:(size - 1)
                        MPI.isend([cobj[], cinc[(switched_idx[1]):(switched_idx[2])]...], hrstc_rank, MSG_ROOT_INC, cw)
                        #println(cinc[(switched_idx[1] - 3):(switched_idx[2] + 3)])
                    end
                end
            end
        end

        ## RECEIVE
        if cb_where == convert(Cint, Gurobi.GRB_CB_MIPNODE)

            rcv = true
            status = false
            message = nothing
            csrc = 1
            cr += 1
            t = Base.time()
            available, stats = MPI.Iprobe(csrc, MSG_SOLUTIONS, cw)
            if available
                status, message = MPI.irecv(csrc, MSG_SOLUTIONS, cw)
            end
            crt += Base.time() - t

            amnt = 0
            min_obj = 0

            if rcv
                if status && message != nothing && typeof(message) != Bool && typeof(message) != Int64

                    for i in 1:length(message[2])
                        Gurobi.GRBcbsolution(cb_data, message[1][i], C_NULL)
                        inc = message[2][i]
                        cinc = Ref{Cdouble}()
                        Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_MIPNODE_OBJBST, cinc)
                        lb = Ref{Cdouble}()
                        Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_MIPNODE_OBJBND, lb)
                        time = Ref{Cdouble}()
                        Gurobi.GRBcbget(cb_data, cb_where, GRB_CB_RUNTIME, time)
                        src = csrc
                        if cinc[] > inc
                            save(logger, [inc, lb[], time[], src])
                        end
                        min_obj = i
                        amnt = i
                    end

                    # println("----------------------------------------------------------------------------")
                    # println("[INFO] Message received from heuristic on rank ", csrc ,".")
                    # println("[INFO] Solution(s) Found: ", amnt, ", Solution(s) Passed: ", min_obj)
                    # println("----------------------------------------------------------------------------")
                    marker = ">>> "
                    #color = "\u001b[36m"
                    for i in 1:length(message[2])
                        #i == min_obj ? marker = " <" : marker = ""
                        println(marker, "rank $(csrc)",", OBJ: ", message[2][i], ", CT: ", message[3][i])
                    end
                    #println("----------------------------------------------------------------------------")
                    recent_update = true
                    status, message = MPI.irecv(csrc, MSG_SOLUTIONS, cw)
                end
            end
        end
    end

    t = Base.time()
    MOIU.attach_optimizer(m)
    grb_model = backend(m).optimizer.model

    user_data = _CallbackUserData(
        grb_model,
        (cb_data, cb_where) -> begin
            callback_rank0(cb_data, cb_where)
            return
        end,
    )

    if heuristic
        ret = GRBsetcallbackfunc(grb_model, grb_callback, user_data)
    end

    user_data_logger = _CallbackUserData(
        grb_model,
        (cb_data, cb_where) -> begin
            callback_logger(cb_data, cb_where)
            return
        end,
    )

    if logger_active
        ret = GRBsetcallbackfunc(grb_model, grb_callback, user_data_logger)
    end

    generation_idx = [m.moi_backend.model_to_optimizer_map[index(p[1])].value,
                      m.moi_backend.model_to_optimizer_map[index(p[length(data.generators)])].value]
    theta_idx = [m.moi_backend.model_to_optimizer_map[index(v[1])].value,
                 m.moi_backend.model_to_optimizer_map[index(v[length(data.buses)])].value]
    power_flow_idx = [m.moi_backend.model_to_optimizer_map[index(f[1])].value,
                      m.moi_backend.model_to_optimizer_map[index(f[length(data.lines)])].value]
    switched_idx = [m.moi_backend.model_to_optimizer_map[index(z[1])].value,
                    m.moi_backend.model_to_optimizer_map[index(z[length(data.lines)])].value]

    println("Variable Indexes:")
    println("generation:", generation_idx)
    println("theta:     ", theta_idx)
    println("power_flow:", power_flow_idx)
    println("switched:  ", switched_idx)

    if start
        for i in 1:length(data.lines)
            grb_idx = m.moi_backend.model_to_optimizer_map[index(z[i])].value
            Gurobi.GRBsetdblattrelement(grb_model, "Start", grb_idx, Cdouble(1.0))
        end
    end

    GRBupdatemodel(grb_model)

    println(string("JuMP model built: ", Base.time() - t))
    t = Base.time()
    GRBoptimize(grb_model)

    #print(Gurobi.get_dblattrarray(grb_model,"X", 1, num_vars(grb_model)))
    ft = Base.time() - ts
    println(string(cs / ft," ",cst / ft," ", cr / ft," ",crt / ft," ", cr, " ", crt, " ", ft))
    objective = 0.0
    solution = [0.0]

    # solution = [value.(p).data...,
    #             value.(v).data...,
    #             value.(f).data...,
    #             value.(z).data...]

    return logger, m#, value.(m[:z]).data
end
