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
include("models/_rotsp.jl")
include("models/_stdcopf.jl")

cd(@__DIR__)

const THETAMAX = 1.2
const THETAMIN = -1.2

grb_env = Gurobi.Env()
cases = [30, 34, 35, 50, 54, 5] #27,#4 9 11, 15,21, 23, 27, 30, 40, 57, 50, 5
cases = [47] #3, 47, 4, 9, 5, 50, 30, 19, 15 34
# 5, 50, 34, 30, 27, 22, 35

PowerGrids.set_csv_path("/home/antonhinneck/projects/github/pglib2csv/pglib/2020-08-21.19-54-30-275/csv")
case_names = PowerGrids.csv_cases(verbose = true)
# PowerGrids.select_csv_case(4) # 30as bus
# data = PowerGrids.loadCase()

# m_opf = build_stdcopf(grb_env, data, threads = 8, outputflag = 1)
# optimize!(m_opf)
# value.(m_opf[:f]).data
# value.(m_opf[:f]).data[(350,)]

# expand(value(m_opf[:f].data), [true for i in 1:length(data.lines)])
#logger, m = solve_rotsp(data, start = true, heuristic = false, threads = 8, time_limit = 6, logger_active = false)
# logger, m, is = solve_otsp(data, start = true, heuristic = false, threads = 8, time_limit = 90, logger_active = false, outputflag = 1)
# ROOT = 0
# root_inc = 1
# for i in 11:11
#     println(value(m[:z][i]))
#     println(is[i])
#     println("----")
# end
# Iea = [Bool.(Int64.(round.(is)))...]
# #Iea = [true for i in 1:length(data.lines)]
# Ies = [false for i in 1:length(data.lines)]
# for i in 1:60
#     Ies[i] = true
# end
# optimizer_terminated = [true]
# logger, stat = solve_rotsp(grb_env, data, Iea, Ies, optimizer_terminated, root_inc, uplink = false, outputflag = 1)
# println(Iea[1:11])
# m = build_stdcopf(grb_env, data, outputflag = 1)
# optimize!(m)
# GRBUjumpconstrbyoptindex(m, 3401)
# iis = GRBcomputeIIS(backend(m).optimizer.model)
# cons = GRButils_getIISconstrs(m)
# for i in cons
#     GRBUjumpconstrbyoptindex(m, i)
# end
# objective_value(m)
# start_dict = Dict{Symbol, Vector{Float64}}()
# push!(start_dict, :p => value.(m[:p]).data)
# push!(start_dict, :f => value.(m[:f]).data)
# push!(start_dict, :v => value.(m[:v]).data)

for c in 22:22
    PowerGrids.select_csv_case(c) # 30as bus
    data = PowerGrids.loadCase()

    logger, m = solve_otsp(data, start = true, heuristic = false, threads = 8, time_limit = 900, logger_active = true)
    GRBtimedout(m) ? timeout(logger) : nothing
    write_log(logger,string("logs_updt/",data.name,"_log_s"))

    # logger, m = solve_otsp(data, start = false, heuristic = false, threads = 8, time_limit = 900, logger_active = true)
    # write_log(logger,string("logs_updt/",data.name,"_log_ns"))
end

# PowerGrids.select_csv_case(4) # 30as bus
# data = PowerGrids.loadCase()
# logger, m = solve_otsp(data, start = false, heuristic = false, threads = 8, time_limit = 900, logger_active = true)
# write_log(logger,string("logs/",data.name,"_log_ns"))

# PowerGrids.set_csv_path("/home/antonhinneck/projects/github/pglib2csv/pglib/2020-08-21.19-54-30-275/csv/sad")
# PowerGrids.csv_cases(verbose = true)

# PowerGrids.select_csv_case(4) # 30as bus
# data = PowerGrids.loadCase()
# println(data.name)

# # logger = solve_TS_MIP(data, heuristic = false, threads = 8, time_limit = 10, logger_active = true)
# # write_log(logger,string("logs/",data.name,"_log_ns"))

# m = build_stdcopf(grb_env, data, outputflag = 1)
# optimize!(m)
# # objective_value(m)
# # start_dict = Dict{Symbol, Vector{Float64}}()
# # push!(start_dict, :p => value.(m[:p]).data)
# # push!(start_dict, :f => value.(m[:f]).data)
# # push!(start_dict, :v => value.(m[:v]).data)

# for c in [4]
#     println(data.name)
#     PowerGrids.select_csv_case(c) # 30as bus
#     data = PowerGrids.loadCase()

#     logger, m = solve_otsp(data, start = true, heuristic = false, threads = 8, time_limit = 90, logger_active = true)
#     write_log(logger,string("logs/",data.name,"_log_s"))

#     logger, m = solve_otsp(data, start = false, heuristic = false, threads = 8, time_limit = 90, logger_active = false)
#     write_log(logger,string("logs/",data.name,"_log_ns"))
# end


# PowerGrids.set_csv_path("/home/antonhinneck/projects/github/pglib2csv/pglib/2020-08-21.19-54-30-275/csv/sad")
# PowerGrids.csv_cases(verbose = true)

# PowerGrids.select_csv_case(4) # 30as bus
# data = PowerGrids.loadCase()
# println(data.name)

# # logger = solve_TS_MIP(data, heuristic = false, threads = 8, time_limit = 10, logger_active = true)
# # write_log(logger,string("logs/",data.name,"_log_ns"))

# m = build_stdcopf(grb_env, data, outputflag = 1)
# optimize!(m)
# # objective_value(m)
# # start_dict = Dict{Symbol, Vector{Float64}}()
# # push!(start_dict, :p => value.(m[:p]).data)
# # push!(start_dict, :f => value.(m[:f]).data)
# # push!(start_dict, :v => value.(m[:v]).data)

# for c in cases
#     println(data.name)
#     PowerGrids.select_csv_case(c) # 30as bus
#     data = PowerGrids.loadCase()

#     logger, m = solve_otsp(data, start = true, heuristic = false, threads = 8, time_limit = 100, logger_active = true)
#     write_log(logger,string("logs/",data.name,"_log_s"))

#     # logger, m = solve_otsp(data, start = false, heuristic = false, threads = 8, time_limit = 5, logger_active = false)
#     # write_log(logger,string("logs/",data.name,"_log_ns"))
# end


