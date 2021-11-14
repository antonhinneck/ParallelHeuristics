using Dates
println(string("Julia loaded: ", Dates.now()))
t = Base.time()
using MPI, Gurobi, JuMP
using MathOptInterface: TerminationStatusCode
using MathOptInterface#: TerminationStatusCode
using Base: time
include("C:/Users/Anton Hinneck/juliaPackages/GitHub/PowerGrids.jl/src/PowerGrids.jl")

include("functions.jl")
include("Model_MIPs.jl")
include("Model_LP.jl")
println(string("Packages loaded: ", time() - t))
const NULL = 3
const ROOT = 0
const HRSTC = 1
const MSG_TERMINATE = 32
const MSG_SOLUTIONS = 33
const MSG_ROOT_INC = 34

const THREADS_ROOT = 12
const THREADS_SLAVE = 16 - THREADS_ROOT

const TIMELIMIT = 1800
const HRSTC_TIMELIMIT = 60
const HRSTC_ACTIVE = true

const THETAMAX = 0.6
const THETAMIN = -0.6

cd(@__DIR__)

datasources = PowerGrids.datasets()

# for (i, d) in enumerate(datasources)
#         print(i," ",d)
# end

d = 4
t = time()
data = PowerGrids.readDataset(datasources[d])
println(string("Load case data", time() - t))

# line_indicators = [true for i in 1:length(data.lines)]
# grb_env = Gurobi.Env()
# ct, status, objective, solution, dual_indicators = solve_TS_LP(grb_env, data, line_indicators, threads = 16)
# logger = solve_TS_MIP(data, heuristic = false, threads = 16, time_limit = 900)
# (1 - 6775002.5586 / objective) * 100

logger = solve_TS_MIPs(data, heuristic = true, threads = 16, time_limit = 900, start = true)
#(1 - 1373989.69 / objective) * 100
