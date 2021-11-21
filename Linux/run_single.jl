using Dates
using MPI, Gurobi, JuMP
using Gurobi: _CallbackUserData, CallbackData
using MathOptInterface: TerminationStatusCode, VariableIndex
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

cd(@__DIR__)

const THETAMAX = 0.6
const THETAMIN = -0.6

grb_env = Gurobi.Env()
cases = [4, 47, 9, 11, 15, 19, 22, 27, 30, 34, 35, 40, 57, 50, 5]

PowerGrids.set_csv_path("/home/antonhinneck/projects/github/pglib2csv/pglib/2020-08-21.19-54-30-275/csv")
PowerGrids.csv_cases(verbose = true)

PowerGrids.select_csv_case(34) # 30as bus
data = PowerGrids.loadCase()

# logger = solve_TS_MIP(data, heuristic = false, threads = 8, time_limit = 10, logger_active = true)
# write_log(logger,string("logs/",data.name,"_log_ns"))

m = build_stdcopf(grb_env, data, outputflag = 1)
optimize!(m)
start_dict = Dict{Symbol, Vector{Float64}}()
push!(start_dict, :p => value.(m[:p]).data)
push!(start_dict, :f => value.(m[:f]).data)
push!(start_dict, :v => value.(m[:v]).data)

logger, m = solve_otsp(data, start = true, heuristic = false, threads = 8, time_limit = 10, logger_active = false, start_dict = start_dict)
# write_log(logger,string("logs/",data.name,"_log_s"))

GRBUjumpconstrbyoptindex(m, 2000)
