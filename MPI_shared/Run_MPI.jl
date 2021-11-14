using MPI, Gurobi, JuMP
using MathOptInterface: TerminationStatusCode
using MathOptInterface#: TerminationStatusCode
using Base: time
include("C:/Users/Anton Hinneck/.julia/packages/PowerGrids/src/PowerGrids.jl")

include("functions.jl")
include("Model_MIP.jl")
include("Model_LP.jl")
include("Model_LP_Duals.jl")
include("Model_MIP_Decomposition.jl")
cd(@__DIR__)

## INITIALIZE MPI
##---------------
MPI.Init()

cw = MPI.COMM_WORLD
size = MPI.Comm_size(cw)
rank = MPI.Comm_rank(cw)

## DEFINING CONSTANTS
##-------------------
const NULL = 3
const ROOT = 0
const MSG_TERMINATE = 32
const MSG_SOLUTIONS = 33
const MSG_INCUMBENT = 34

const TIMELIMIT = 1800
const HRSTC_TIMELIMIT = 60
const HRSTC = true

const THETAMAX = 0.6
const THETAMIN = -0.6

## DEFINING FUNCTIONS
##-------------------
@inline function irecv_msg(src::I where I <: Integer, msg_type::I where I <: Integer)

        solutions = nothing

        (hasdata, stat) = MPI.Iprobe(src, msg_type, cw)
        if hasdata
                solutions, mpi_status = MPI.recv(src, msg_type, cw)
        end

        return hasdata, solutions
end

@inline function recv_msg(src::I where I <: Integer, msg_type::I where I <: Integer)

        terminate = false
        message = nothing
        has_data = false

        stat = MPI.Probe(src, msg_type, cw)
        count = MPI.Get_count(stat, Int32)

        if count == NULL
                terminate = true
                println("[INFO] TERMINATE RECEIVED ON RANK ", rank,". SHUTTING DOWN.")
        end

        if !terminate

                if msg_type == MSG_INCUMBENT
                        message, has_data = MPI.recv(src, msg_type, cw)
                        try
                                if typeof(message) == Array{Float64,1}
                                        has_data = true
                                else
                                        has_data = false
                                end
                        catch e
                                has_data = false
                        end
                else
                        message, has_data = MPI.recv(src, msg_type, cw)
                end
        end

        return has_data, message, terminate
end

cd(@__DIR__)

datasources = PowerGrids.datasets()
#21 bad
#23 broken
for i in 14:14

        data = PowerGrids.readDataset(datasources[i])

        # Build Data Structures
        #----------------------
        solution_sent = Vector{Bool}()
        solutions_stack = Vector{Vector{Float64}}()
        objective_stack = Vector{Float64}()
        time_stack = Vector{Float64}()

        if rank == ROOT

                logger = solve_TS_MIP(data, heuristic = HRSTC, threads = 12, time_limit = TIMELIMIT)
                optimizer_terminated = true
                write_log(logger,"log")
                println("[INFO] RANK ",rank,": WAITING FOR WORKER THREADS TO TERMINATE.")
                sreq = MPI.isend(true, ROOT, MSG_TERMINATE, cw)
                (inds, stats) = MPI.Waitsome!([sreq])

        elseif rank != ROOT
        # AUXILLIARY HERISTIC
        #--------------------

                grb_env = Gurobi.Env()
                idx_new_solution = 1
                optimizer_terminated = [false]
                rreq = MPI.Irecv!(optimizer_terminated, ROOT,  MSG_TERMINATE, cw)

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

                function get_priority_list(idxs::Array{I,1} where I <: Integer, first::I where I <: Integer, last::I where I <: Integer)

                    @assert first <= last
                    @assert last <= length(idxs)

                    plist = Vector{Int64}()
                    len_idxs = length(idxs)
                    for i in 1:last
                        push!(plist, idxs[len_idxs - i - 1])
                    end
                    return plist
                end

                graph = PowerGrids.toGraph(data)

                init = false
                kill = false
                incumbent_updated = false
                solution_found = false
                incumbent_sol = Vector{Float64}()
                incumbent_obj = 0.0
                idxs = Vector{Int64}()
                line_indicators = [true for i in 1:length(data.lines)]
                constraint_indicators = [true for i in 1:length(data.lines)]
                dual_indicators = [false for i in 1:length(data.lines)]
                mipstart = [true for i in 1:length(data.lines)]
                start_plist = 1
                len_plist = 180
                duals_computed = false
                line_idxs = data.lines

                while (optimizer_terminated[1] == false && HRSTC)

                        ## Initialization
                        ##---------------
                        if !init

                                ct, status, objective, solution, dual_indicators = solve_TS_LP(grb_env, data, line_indicators, threads = 4)

                                if status == TerminationStatusCode(1)
                                        solution_found = true
                                        incumbent_updated = true
                                        push!(solution_sent, false)
                                        push!(solutions_stack, solution)
                                        push!(objective_stack, objective)
                                        push!(time_stack, ct)
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
                        if init && optimizer_terminated[1] != true && rank == 1

                                if !duals_computed
                                        runtime, status, objective, solution, a1, a2 = solve_TS_LP_Duals(grb_env, data, line_indicators, threads = 4)

                                        duals = Array{Float64, 1}(undef, length(data.lines))
                                        for i in 1:length(data.lines)
                                            if line_indicators[i]
                                                duals[i] = a1[i]
                                            else
                                                duals[i] = a2[i]
                                            end
                                        end

                                        line_idxs = sortperm(duals)#1354
                                        #line_idxs = sortperm(duals, by=abs, rev = false)
                                        duals_computed = true
                                end

                                #plist = get_priority_list(line_idxs, 1, 200) #1354
                                plist = get_priority_list(line_idxs, start_plist, start_plist + len_plist)

                                for i in 1:length(plist)
                                        constraint_indicators[plist[i]] = false
                                end

                                solve_TS_MIP_Deco(grb_env, data, line_indicators, constraint_indicators, optimizer_terminated, mipstart, threads = 4, time_limit = TIMELIMIT)
                                if (start_plist + len_plist) <= length(data.lines)
                                        start_plist += len_plist
                                end
                                #=
                                if status == TerminationStatusCode(1) || has_values
                                        for j in 1:length(solutions)
                                                if length(solutions[j]) != 1
                                                        push!(solution_sent, false)
                                                        push!(solutions_stack, solutions[j])
                                                        push!(objective_stack, objectives[j])
                                                        push!(time_stack, time)
                                                end
                                        end
                                        transmit_solution()
                                end=#
                        end
                end

                #MPI.isend(true, 0, MSG_SOLUTIONS, cw)
        end
end

println("[INFO] RANK ", rank, " TERMINATED.")
MPI.Finalize()
