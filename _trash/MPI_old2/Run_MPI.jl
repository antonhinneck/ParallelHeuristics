using MPI, Gurobi, JuMP
using MathOptInterface: TerminationStatusCode
using MathOptInterface#: TerminationStatusCode
using Base: time
include("C:/Users/Anton Hinneck/.julia/packages/PowerGrids/src/PowerGrids.jl")

include("functions.jl")
include("Model_switching.jl")
include("Model_flow_relax.jl")
include("Model_switching_decomp.jl")
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
const MSG_TERMINATE = 0
const MSG_SOLUTIONS = 1
const MSG_INCUMBENT = 2

const TIMELIMIT = 120
const HRSTC_TIMELIMIT = 20
const HRSTC = true

const THETAMAX = 0.5235
const THETAMIN = -0.5235

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

for i in 3:3

        data = PowerGrids.readDataset(datasources[i])

        # Build Data Structures
        #----------------------
        solution_sent = Vector{Bool}()
        solutions_stack = Vector{Vector{Float64}}()
        objective_stack = Vector{Float64}()
        time_stack = Vector{Float64}()

        if rank == ROOT

                logger = solve_TS_MILP(data, heuristic = HRSTC, threads = 3, time_limit = TIMELIMIT)
                optimizer_terminated = true
                write_log(logger,"log")
                println("[INFO] RANK ",rank,": WAITING FOR WORKER THREADS TO TERMINATE.")
                for i in 1:HRSTC_TIMELIMIT

                        status, solutions = MPI.irecv(1, MSG_SOLUTIONS, cw)

                        if status
                                break
                        end
                        sleep(1)
                end

                MPI.send(Array{Float64,1}(undef, 0), 1, MSG_TERMINATE, cw)

        elseif rank != ROOT
        # AUXILLIARY HERISTIC
        #--------------------

                grb_env = Gurobi.Env()
                idx_new_solution = 1
                optimizer_terminated = false

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
                                MPI.send([new_solutions, new_objectives, new_ctimes], ROOT, MSG_SOLUTIONS, cw)
                                for i in idx_new_solution:length(solution_sent)
                                        solution_sent[i] == true
                                end

                                idx_new_solution += amnt_new_sols
                        end
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

                while (optimizer_terminated == false || optimizer_terminated == nothing && HRSTC)

                        ## Initialization
                        ##---------------
                        if !init

                                time, status, objective, solution, dual_indicators = solve_TS_LP_RLX(grb_env, data, line_indicators, threads = 1)

                                if status == TerminationStatusCode(1)
                                        solution_found = true
                                        incumbent_updated = true
                                        push!(solution_sent, false)
                                        push!(solutions_stack, solution)
                                        push!(objective_stack, objective)
                                        push!(time_stack, time)
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
                        if init && optimizer_terminated != true

                                status, incumbent, terminate = recv_msg(ROOT, MSG_INCUMBENT)

                                if !terminate
                                        if status
                                                #if incumbent[1] < incumbent_obj

                                                        println("[INFO] INCUMBENT UPDATED ON RANK ",rank)
                                                        incumbent_updated = true
                                                        incumbent_obj = incumbent[1]
                                                        incumbent_sol = incumbent[2:length(incumbent)]
                                                        #PowerGrids.solutionToLineIndicators!(line_indicators, incumbent_sol, data)
                                                        #time, status, objective, solution, dual_indicators = solve_TS_LP_RLX(grb_env, data, line_indicators)

                                                #end
                                        else

                                        end
                                else

                                        optimizer_terminated = true

                                end

                                ## Run heuristic and transmit
                                ##---------------------------
                                if optimizer_terminated != true

                                        # TODO: Implement heuristic restart if no idxs left
                                        if incumbent_updated && false
                                                constraint_indicators = [true for i in 1:length(data.lines)]
                                                idxs = PowerGrids.rmLines!(constraint_indicators, data, 200, dual_override = dual_indicators)
                                                incumbent_updated = false
                                        else
                                                constraint_indicators = PowerGrids.shift!(idxs, data, 200)
                                        end

                                        constraint_indicators = [true for i in 1:length(data.lines)]
                                        li = [true for i in 1:length(data.lines)]
                                        PowerGrids.rmLines!(constraint_indicators, data, 100)
                                        PowerGrids.solutionToLineIndicators!(li, incumbent_sol, data)
                                        time, status, has_values, objectives, solutions = solve_TS_MILP_DEC(grb_env, data, li, constraint_indicators, threads = 1, time_limit = HRSTC_TIMELIMIT)

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
                                        end
                                end
                        end
                end

                #MPI.isend(true, 0, MSG_SOLUTIONS, cw)
        end
end

println("[INFO] RANK ", rank, " TERMINATED.")
MPI.Finalize()
