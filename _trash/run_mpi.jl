using MPI, Hwloc

const ROOT_RANK = 0

MPI.Init()

comm = MPI.COMM_WORLD
size = MPI.Comm_size(comm)
rank = MPI.Comm_rank(comm)

MPI.Barrier(comm)

## Init MPI vars
################

res_upw_k = nothing
res_dwn_k = nothing
gen_k = nothing
max_imbalance = nothing
lbk = nothing
num_scatter_els = nothing

worst_case_imbalance = 0.0

## Load data
############

include("/home/antonhinneck/projects/github/PowerGrids.jl/src/PowerGrids.jl")
using .PowerGrids
using JuMP
using Gurobi
using JLD
using LinearAlgebra: diagm
using MathOptInterface
using Dates
include("MPIutil.jl")
include("utils/logger.jl")
include("models/_dcopf_con.jl")
include("models/_osrmp.jl")
include("models/_osrsp.jl")
include("functions.jl")

grb_env = Gurobi.Env()
THETAMAX = 0.6
THETAMIN = -0.6

PowerGrids.set_csv_path("/home/antonhinneck/projects/github/pglib2csv/pglib/2020-08-21.19-54-30-275/csv")
PowerGrids.csv_cases(verbose = false)
PowerGrids.select_csv_case(3)
data = PowerGrids.loadCase()
data_pre = PowerGrids.loadCase()
periods = [i for i in 1:24]
imbalance_costs = 500
reserve_costs = 400
hld = zeros(246, 24)
hld[1:123,:] = JLD.load("hourly_load_data_010521_010921.jld")["data"]
hld[124:246,:] = JLD.load("hourly_load_data_010521_010921.jld")["data"]
RUc = [data.generator_Pmax[g] * 0.3 for g in data.generators]
RDc = [data.generator_Pmax[g] * 0.3 for g in data.generators]
M = 10000
M2 = 2 * THETAMAX

contingencies = [i for i in 1:240]
ngens = length(data.generators)
nlines = length(data.lines)
total_contingencies = [i for i in 1:(nlines + ngens)]
contingencies_els = [nlines, ngens]
contingencies_A = zeros(nlines + ngens, nlines + ngens) + diagm(ones(nlines + ngens))

PowerGrids.__splitBus!(data, 49, 2, smart = false)
# PowerGrids.__splitBus!(data, 100, 2, smart = false)

added_contingencies = Vector{Int64}()

if rank == 0

    included_contingencies = Vector{Int64}()
    ctr_ex = 0
    for c in total_contingencies
        mymod = solve_dcopf_con(grb_env, data_pre, c, threads = 1)
        optimize!(mymod)
        if termination_status(mymod) == MathOptInterface.TerminationStatusCode(1)
            push!(included_contingencies, c)
        else
            global ctr_ex += 1
        end
    end
    println(string("Excluded contingencies: ", ctr_ex))

end

######################
## Outer Iterations ##
######################
for i in 1:2

    #########################################
    ## MASTER PROBLEM  ######################
    #########################################
    if rank == 0

        m = solve_OSRMP(grb_env, data, added_contingencies, periods, x0 = PowerGrids.sol_allActive(data; select = :first))
        optimize!(m)
        res_upw_k, res_dwn_k, gen_k, max_imbalance, lbk = model_results(m)

        global res_upw_k = MPI.bcast(res_upw_k, 0, comm)
        global res_dwn_k = MPI.bcast(res_dwn_k, 0, comm)
        global gen_k = MPI.bcast(gen_k, 0, comm)
        global max_imbalance = MPI.bcast(max_imbalance, 0, comm)
        global lbk = MPI.bcast(lbk, 0, comm)

        MPI.Barrier(comm)
        println("MP over 0")

    else

        global res_upw_k = MPI.bcast(res_upw_k, 0, comm)
        global res_dwn_k = MPI.bcast(res_dwn_k, 0, comm)
        global gen_k = MPI.bcast(gen_k, 0, comm)
        global max_imbalance = MPI.bcast(max_imbalance, 0, comm)
        global lbk = MPI.bcast(lbk, 0, comm)

        MPI.Barrier(comm)

    end

    ############################################
    #### SUB PROBLEM  ##########################
    ############################################
    #### Send data ##
    #################

    isroot = (rank == 0)
    A = isroot ? MPIutil_scatter_pad(included_contingencies) : nothing
    global num_scatter_els = isroot ? MPI.bcast(Int(Base.ceil(Base.size(included_contingencies, 1) / size)), 0, comm) : MPI.bcast(num_scatter_els, 0, comm)
    MPI.Barrier(comm)

    this_thread_contingencies = Array{Int64, 1}(undef, num_scatter_els)
    MPI.Scatter!(A, this_thread_contingencies, 0, comm)
    MPI.Barrier(comm)

    ########################
    ## Solve sub problems ##
    ########################
    global worst_case_imbalance = 0.0
    global worst_case_contingency = -1
    auxlines = get_auxlines(data)
    switching_solutions = Array{Bool, 2}(undef, Base.size(this_thread_contingencies, 1), Base.size(auxlines, 1))
    imbalances_k = Vector{Int64}()
    imbalances_obj = Vector{Float64}()
    times_k = Vector{Float64}()
    lp_only = Vector{Int64}()
    MPI.Barrier(comm)
    println(string("starting", rank))
    t0 = Dates.now()
    mycounter = 1
    for k in this_thread_contingencies
        if (k != -1)
            this_lp_only = true
            outputflag = (k == 32) ? 1 : 0
            msp = solve_OSRSP(grb_env, data, k, gen_k, res_dwn_k, res_upw_k, periods, nlines = nlines, outputflag = outputflag)
            if mycounter == 1
                t0 = Dates.now()
            end
            optimize!(msp)
            thisobj = objective_value(msp)
            if thisobj > worst_case_imbalance
                this_lp_only = false
                msp = solve_OSRSP(grb_env, data, k, gen_k, res_dwn_k, res_upw_k, periods, nlines = nlines, x0 = PowerGrids.sol_allActive(data; select = :first))
                optimize!(msp)
                thisobj = objective_value(msp)
                if thisobj > worst_case_imbalance
                    global worst_case_imbalance = objective_value(msp)
                    global worst_case_contingency = k
                end
            end
            if this_lp_only
                switching_solutions[mycounter, :] = [true for i in 1:Base.size(auxlines, 1)]
            else
                for al in auxlines
                    print(value(msp[:switched][al]))
                end
            end
                    

            push!(imbalances_k, k)
            push!(imbalances_obj, thisobj)
            push!(lp_only, this_lp_only)
            push!(times_k, (Dates.now() - t0).value)
        end
        # if mycounter % 10 == 0 && mycounter > 9
        #     gathered_imbalances = MPI.Gather([worst_case_imbalance], ROOT_RANK, comm)
        #     #MPI.Barrier(comm)
        #     global worst_case_imbalance = isroot ? MPI.bcast(maximum(gathered_imbalances), ROOT_RANK, comm) : MPI.bcast(nothing, ROOT_RANK, comm)
        #     #println(worst_case_imbalance)
        #     MPI.Barrier(comm)
        # end
        mycounter += 1
    end

    # open(string(rank,"-data16.csv"), "w") do io
    #     write(io, "k, ")
    #     write(io, "obj, ")
    #     write(io, "lp_only, ")
    #     write(io, "time\n")
    #     len = length(this_thread_contingencies)
    #     for i in 1:len
    #         if this_thread_contingencies[i] != -1
    #             write(io, string(this_thread_contingencies[i],", "))
    #             write(io, string(imbalances_obj[i],", "))
    #             write(io, string(lp_only[i],", "))
    #             write(io, string(times_k[i],"\n"))
    #         end
    #     end
    # end

    println(string(rank, " finished after ", Dates.now()-t0,"."))
    MPI.Barrier(comm)

    #################
    ## Gather data ##
    #################

    post_sub_contingencies = MPI.Gather([worst_case_contingency], ROOT_RANK, comm)
    post_sub_imbalances = MPI.Gather([worst_case_imbalance], ROOT_RANK, comm)
    MPI.Barrier(comm)

    if isroot

        println(post_sub_contingencies)
        println(post_sub_imbalances) 
        idx = argmax(post_sub_imbalances)
        push!(added_contingencies, post_sub_contingencies[idx])
        println(string("max_imbalance"))

    end
    
    MPI.Barrier(comm)
#############################
end ## Outer Iteration End ##
#############################

MPI.Finalize()