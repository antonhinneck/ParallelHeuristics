using MPI, Gurobi, JuMP
using MathOptInterface: TerminationStatusCode
using MathOptInterface#: TerminationStatusCode
using Base: time
include("C:/Users/Anton Hinneck/juliaPackages/GitHub/PowerGrids.jl/src/PowerGrids.jl")

include("functions.jl")
include("Model_MIP.jl")
include("Model_LP.jl")
include("Model_LP_Duals.jl")
include("Model_MIP_Decomposition.jl")
cd(@__DIR__)

const THETAMAX = 0.6
const THETAMIN = -0.6

datasources = PowerGrids.datasets()
data = PowerGrids.readDataset(datasources[3])

grb_env = Gurobi.Env()
line_indicators = [true for i in 1:length(data.lines)]
solve_TS_LP(grb_env, data, line_indicators, threads = 4)

 1 - 1101720.4454 / 1121708.69
