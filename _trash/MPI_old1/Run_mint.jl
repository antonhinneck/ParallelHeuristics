using Gurobi, JuMP
using MathOptInterface: TerminationStatusCode
using Base: time
include("C:/Users/Anton Hinneck/.julia/packages/PowerGrids/src/PowerGrids.jl")

include("functions.jl")
include("Model_switching.jl")

datasources = PowerGrids.datasets()

for i in 6:6

        data = PowerGrids.readDataset(datasources[i])
        res1, res2 = solve_TS_MILP(data)

end
