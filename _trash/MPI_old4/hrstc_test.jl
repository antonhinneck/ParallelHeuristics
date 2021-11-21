using MPI, Gurobi, JuMP
using MathOptInterface: TerminationStatusCode
using Base: time
using LightGraphs
include("C:/Users/Anton Hinneck/.julia/packages/PowerGrids/src/PowerGrids.jl")

include("functions.jl")
include("Model_switching.jl")
include("Model_flow_relax.jl")
include("Model_flow_relax_duals_new.jl")
include("Model_switching_decomp.jl")

env = Gurobi.Env()
datasources = PowerGrids.datasets(true)

data = PowerGrids.readDataset(datasources[10])

THETAMAX = 0.6
THETAMIN = -0.6

line_indicators = [true for i in 1:length(data.lines)]
dual_indicators = [false for i in 1:length(data.lines)]
dual_probe = [false for i in 1:length(data.lines)]
runtime, status, objective, solution, duals = solve_TS_LP_DUAL(env, data, line_indicators)


THETAMAX = 0.6
THETAMIN = -0.6
line_indicators = [true for i in 1:length(data.lines)]
constraint_indicators = [true for i in 1:length(data.lines)]
d = solve_TS_LP_RLX(env, data, line_indicators)
m = d[6]
t = m.moi_backend.model_to_optimizer_map

m = Model()

@variable(m, t >= 0)

@objective(m, Min, t)

optimize!(m, with_optimizer(Gurobi.Optimizer))

m.moi_backend.model_to_optimizer_map[index(t)].value
using MathOptInterface
m.moi_backend.optimizer_to_model_map[MathOptInterface.VariableIndex(2500)]

res = solve_TS_MILP_DEC(env, data, line_indicators, constraint_indicators, threads = 4, time_limit = 30)

line_indicators = [true for i in 1:length(data.lines)]

d = solve_TS_LP_RLX(env, data, line_indicators)

solve_TS_MILP(data, threads = 4)
graph = PowerGrids.toGraph(data)

ST = PowerGrids.bfs(graph.Graph)

adjlst = PowerGrids.adjacency_list(ST)

#line_vector = PowerGrids.line_vector(adjlst, data, returnType = :bool)
line_indicators = [true for i in 1:length(data.lines)]
constraint_indicators = [true for i in 1:length(data.lines)]

PowerGrids.rmLines!(constraint_indicators, data, 50)

res = solve_TS_MILP_DEC(data, line_indicators, constraint_indicators, threads = 4, time_limit = 30)

res

#=
grb_model = backend(res[5]).optimizer.model.inner

nv = Gurobi.get_intattr(grb_model, "NumVars")
ns = Gurobi.get_intattr(grb_model, "SolCount")
sol = 1
@assert sol <= Gurobi.get_intattr(grb_model, "SolCount")
Gurobi.set_int_param!(grb_model, "SolutionNumber", sol)
Gurobi.get_dblattrarray(grb_model, "Xn", 1, nv)

Gurobi.get_dblattrarray(grb_model, "X", 1, nv)
=#
#res[5][:switched][1720]value

vref = Vector{VariableRef}()
vidx = Vector{Int64}()

for (i, value) in enumerate(res[5][:switched])
    println(i, " ", value)
    push!(vref, value)
    push!(vidx, vref[i].index.value)
end
length(data.lines)
minimum(vidx)

res[5][:switched][data.lines[1721]]

keys(res[5][:switched])

MOI.VectorOfVariables(vref)

res = solve_TS_MILP(data, threads = 4, time_limit = 30)

lvec = [true for i in 1:length(data.lines)]

overflow = solve_TS_LP_ADD(data, line_vector)
#test = solve_TS_LP(data)

v = [true for i in 1:length(data.lines)]
for i in 1:5

    M = Model()

    @variable(M, x >= 0)

    @objective(M, Min, x)

    optimize!(M, with_optimizer(Gurobi.Optimizer))

end

result = solve_TS_MILP_DEC(data, line_vector, threads = 1, time_limit = 2)

saturated_lines = Vector{Int64}()

for i in 1:length(overflow)

    if overflow[2][i] > 0
        push!(saturated_lines, data.lines[i])
    end
end

saturated_lines

solve_TS_LP(data)

solve_TS_MILP(data, time_limit = 60)
