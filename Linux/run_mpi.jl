using Dates
println(string("Julia loaded: ", Dates.now()))
t = Base.time()
using MPI, Gurobi, JuMP
using Gurobi: _CallbackUserData, CallbackData
using MathOptInterface: TerminationStatusCode
# using MathOptInterface#: TerminationStatusCode
using Base: time
using Base: cconvert, unsafe_convert, broadcastable
using Dates
include("/home/antonhinneck/projects/github/PowerGrids.jl/src/PowerGrids.jl")

include("utils/misc_utils.jl")
include("utils/grb_utils.jl")
include("utils/debug_utils.jl")
include("utils/mpi_utils.jl")
include("models/_otsp.jl")
include("models/_stdcopf.jl")
include("models/_rotsp.jl")
println(string("Packages loaded: ", time() - t))
cd(@__DIR__)

## INITIALIZE MPI
##---------------
t = time()
MPI.Init()
cw = MPI.COMM_WORLD
size = MPI.Comm_size(cw)
rank = MPI.Comm_rank(cw)
println(string("MPI initialization: ", time() - t," rank ", rank))

## DEFINING CONSTANTS
##-------------------
const NULL = 3
const ROOT = 0
const HRSTC = 1
const MSG_TERMINATE = 11
const MSG_SOLUTIONS = 12
const MSG_ROOT_INC = 13

const THREADS_ROOT = 4
const THREADS_SLAVE = 8 - THREADS_ROOT

const TIMELIMIT = 900
const HRSTC_TIMELIMIT = 900
const HRSTC_ACTIVE = true

const THETAMAX = 1.2
const THETAMIN = -1.2

cd(@__DIR__)
grb_env = Gurobi.Env()

PowerGrids.set_csv_path("/home/antonhinneck/projects/github/pglib2csv/pglib/2020-08-21.19-54-30-275/csv")

#[, 34, 35, 50, 54, 5] 30 35 50
for i in 27:27

        t = time()
        PowerGrids.select_csv_case(i) # 30as bus
        data = PowerGrids.loadCase()
        println(string("Load case data", time() - t))

        # Build Data Structures
        #----------------------
        solution_sent = Vector{Bool}()
        solutions_stack = Vector{Vector{Float64}}()
        objective_stack = Vector{Float64}()
        time_stack = Vector{Float64}()

        if rank == ROOT

                tr = time()
                logger, model = solve_otsp(data, heuristic = HRSTC_ACTIVE, threads = THREADS_ROOT, time_limit = TIMELIMIT)
                optimizer_terminated = [true]
                write_log(logger,string("logs/",data.name,"_log_p"))
                println("[INFO] RANK ",rank,": WAITING FOR WORKER THREADS TO TERMINATE.")
                sreq = MPI.isend(optimizer_terminated, HRSTC, MSG_TERMINATE, cw)
                MPI.Wait!(sreq)

        elseif rank == HRSTC
        # AUXILLIARY HERISTIC
        #--------------------

                th = time()
                grb_env = Gurobi.Env()
                idx_new_solution = 1
                optimizer_terminated = [false]
                rreq = MPI.Irecv!(optimizer_terminated, ROOT,  MSG_TERMINATE, cw)
                full_iterations = Vector{Float64}()

                @inline function transmit_solution()

                        output = false
                        amnt_sols = length(solution_sent)
                        amnt_new_sols = amnt_sols - (idx_new_solution - 1)

                        #idx_last_sent_solution
                        len_sol = length(solutions_stack[1])

                        new_solutions = Vector{Vector{Float64}}()
                        new_objectives = Vector{Float64}()
                        new_ctimes = Vector{Float64}()

                        if (idx_new_solution - 1) < amnt_sols
                                for i in idx_new_solution:amnt_sols
                                                push!(new_solutions, solutions_stack[i])
                                                push!(new_objectives, objective_stack[i])
                                                push!(new_ctimes, time_stack[i])
                                end

                                sreq = MPI.isend([new_solutions, new_objectives, new_ctimes], ROOT, MSG_SOLUTIONS, cw)
                                (inds, stats) = MPI.Waitsome!([sreq])

                                for i in idx_new_solution:length(solution_sent)
                                        solution_sent[i] == true
                                end

                                idx_new_solution += amnt_new_sols
                        end
                end

                init = false
                kill = false
                incumbent_updated = false
                solution_found = false
                incumbent_sol = Vector{Float64}()
                incumbent_obj = 0.0
                idxs = Vector{Int64}()
                Iea = [true for i in 1:length(data.lines)]
                Ies = [false for i in 1:length(data.lines)]
                #mipstart = [true for i in 1:length(data.lines)]
                n = 40
                ??n = 10
                sc_vals = zeros(length(data.lines))
                dp = deepcopy(data.lines)
                switching_criterion = PowerGrids.get_sensitivities_lpsc
                root_inc = Array{Float64, 1}(undef, length(data.lines) + 1)
                root_inc[2:(length(data.lines) + 1)] = ones(length(data.lines))
                root_inc[1] = Inf64

                while (optimizer_terminated[1] == false && HRSTC_ACTIVE)
                        ## Initialization
                        ##---------------
                        if !init

                                m_opf = build_stdcopf(grb_env, data, threads = THREADS_SLAVE, outputflag = 0)
                                optimize!(m_opf)
                                ct = 0.0
                                status = termination_status(m_opf)
                                objective = 0.0

                                if status == TerminationStatusCode(1)
                                        solution = [value.(m_opf[:p]).data...,
                                                        convertArray(Float64, Iea)...,
                                                        value.(m_opf[:v]).data...,
                                                        expand(value.(m_opf[:f]).data, Iea)...]
                                        ct = Ref{Cdouble}()
                                        GRBgetdblattr(backend(m_opf).optimizer.model, "Runtime", ct)
                                        objective = objective_value(m_opf)
                                        solution_found = true
                                        incumbent_updated = true
                                        push!(solution_sent, false)
                                        push!(solutions_stack, solution)
                                        push!(objective_stack, objective)
                                        push!(time_stack, ct[])
                                        incumbent_sol = solution
                                        incumbent_obj = objective
                                        transmit_solution()
                                        #dual_indicators = new_duals
                                        init = true
                                end
                        end

                        ## Heuristic
                        ##----------
                        ## Check for new solutions
                        ## Obtain duals
                        ##------------------------
                        if init && optimizer_terminated[1] != true

                                m_opf = build_stdcopf(grb_env, data, Iea = Iea, threads = THREADS_SLAVE)
                                optimize!(m_opf)
                                ct = Ref{Cdouble}()
                                status = termination_status(m_opf)
                                objective = 0.0
                                status = termination_status(m_opf)
                                if status == TerminationStatusCode(1)
                                        GRBgetdblattr(backend(m_opf).optimizer.model, "Runtime", ct)
                                        objective = objective_value(m_opf)
                                        sc_vals = switching_criterion(data, m_opf)
                                        dp = sortperm(sc_vals, rev = true)
                                else
                                        println("ERROR: PRIORITY LIST COULD NOT BE CREATED.")
                                end

                                Ies = Array{Bool, 1}(undef, length(data.lines))
                                for i in 1:length(dp)
                                        if i <= n
                                                Ies[dp[i]] = true
                                        else
                                                Ies[dp[i]] = false
                                        end

                                end

                                # for i in data.lines
                                #         @assert root_inc[i + 1] == Float64(Iea[i])
                                # end
                                
                                root_inc, tstat = solve_rotsp(grb_env, data, Iea, Ies, optimizer_terminated, root_inc, threads = THREADS_SLAVE, time_limit = HRSTC_TIMELIMIT, outputflag = 1, mipgap = 10e-5)

                                # message, status = MPI.recv(ROOT, MSG_ROOT_INC, cw)
                                Iea = [Bool.(Int64.(round.(root_inc[2:(length(data.lines) + 1)])))...]

                                if tstat == TerminationStatusCode(1)
                                        if n + ??n < length(data.lines)
                                                n += ??n
                                        end
                                else
                                        if n + ??n < length(data.lines)
                                                n += ??n
                                        end
                                end

                                available, stats = MPI.Iprobe(ROOT, MSG_TERMINATE, cw)
                                if available
                                        status, message = MPI.irecv(ROOT, MSG_TERMINATE, cw)
                                        optimizer_terminated = [true]
                                        break
                                end
                                println("Rank 1: Next iteration.")
                        end

                        push!(full_iterations, time() - th)
                        th = time()
                end
        end

        if rank == HRSTC
                open(string("logs/",data.name,"_iterations.txt"), "w") do io
                        write(io, "time\n")
                        for fi in full_iterations
                                write(io, string(fi, "\n"))
                        end
                end
        end
end

println("[INFO] RANK ", rank, " TERMINATED.")
MPI.Finalize()