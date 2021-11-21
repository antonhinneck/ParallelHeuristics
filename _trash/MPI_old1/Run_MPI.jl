using MPI, Gurobi, JuMP
using MathOptInterface: TerminationStatusCode
using Base: time
include("C:/Users/Anton Hinneck/.julia/packages/PowerGrids/src/PowerGrids.jl")

include("functions.jl")
include("Model_switching.jl")
include("Model_flow.jl")
include("Model_flow_relax.jl")
include("Model_switching_decomp.jl")

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

const TIMELIMIT = 240
const HRSTC_TIMELIMIT = 40
const HRSTC = true

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

                message, has_data = MPI.recv(src, msg_type, cw)

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

                #MPI.send(Array{Float64,1}(undef, 0), 1, MSG_TERMINATE, cw)
                res1, res2 = solve_TS_MILP(data, heuristic = HRSTC, threads = 3, time_limit = TIMELIMIT)
                optimizer_terminated = true

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

                #stat = MPI.Probe(ROOT, MSG_TERMINATE, cw)
                #count = MPI.Get_count(stat, Int32)
                #data, status = MPI.recv(9999999)
                #println(count)

                grb_env = Gurobi.Env()
                idx_new_solution = 1
                optimizer_terminated = false

                #hasdata, message, terminate = recv_msg(ROOT, MSG_TERMINATE)
                #terminate ? optimizer_terminated = true : optimizer_terminated = false

                @inline function transmit_solution()

                        output = false
                        amnt_sols = length(solution_sent)
                        amnt_new_sols = amnt_sols - (idx_new_solution - 1)

                        #idx_last_sent_solution
                        len_sol = length(solutions_stack[1])

                        new_solutions = Vector{Vector{Float64}}()
                        new_objectives = Vector{Float64}()
                        new_ctimes = Vector{Float64}()

                        if idx_new_solution < amnt_sols
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
                idxs = Vector{Int64}()
                kill = false
                incumbent_sol = Vector{Float64}()
                constraint_indicators = [true for i in 1:length(data.lines)]
                line_indicators = [true for i in 1:length(data.lines)]

                while optimizer_terminated == false || optimizer_terminated == nothing

                        if init && optimizer_terminated != true

                                status, incumbent, terminate = recv_msg(ROOT, MSG_INCUMBENT)

                                if !terminate
                                        PowerGrids.solutionToLineIndicators!(line_indicators, incumbent, data)
                                else
                                        optimizer_terminated = true
                                end
                        end

                        # HEURISTIC 2:
                        # RELAXED LP
                        #-------------

                        if !init && optimizer_terminated != true

                                line_vector = ones_bool(length(data.lines))
                                time, status, objective, solution = solve_TS_LP_RLX(grb_env, data, line_vector)

                                if status == TerminationStatusCode(1) || has_values
                                        push!(solution_sent, false)
                                        push!(solutions_stack, solution)
                                        push!(objective_stack, objective)
                                        push!(time_stack, time)
                                end
                        end

                        # HEURISTIC 2:
                        # DECOMPOSED MODELS
                        #------------------

                        if optimizer_terminated != true
                                if !init
                                        idxs = PowerGrids.rmLines!(constraint_indicators, data, 30)
                                elseif init
                                        constraint_indicators = PowerGrids.shift!(idxs, data, 30)
                                end

                                status == TerminationStatusCode(2)
                                has_values = false
                                if constraint_indicators != nothing
                                        time, status, has_values, objectives, solutions = solve_TS_MILP_DEC(grb_env, data, line_indicators, constraint_indicators, threads = 1, time_limit = HRSTC_TIMELIMIT)
                                else
                                        print("[INFO] HEURISTIC ON RANK ",rank," TERMINATED")
                                        optimizer_terminated = true
                                end

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

                        init = true
                end

                MPI.isend(true, 0, MSG_SOLUTIONS, cw)
        end
end

println("[INFO] RANK ", rank, " TERMINATED.")
MPI.Finalize()
