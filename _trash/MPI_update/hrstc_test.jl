using MPI, Gurobi, JuMP
using MathOptInterface: TerminationStatusCode
using Base: time
using LightGraphs
include("C:/Users/Anton Hinneck/.julia/packages/PowerGrids/src/PowerGrids.jl")

include("functions.jl")
include("Model_MIP.jl")
include("Model_LP.jl")
include("Model_LP_Duals.jl")
include("Model_MIP_Decomposition.jl")

grb_env = Gurobi.Env()
datasources = PowerGrids.datasets(true)

data = PowerGrids.readDataset(datasources[14])

THETAMAX = 0.6
THETAMIN = -0.6

#logger = solve_TS_MIP(data, heuristic = true, threads = 16, time_limit = 3600)
#write_log(logger,"log")

#logger = solve_TS_MIP(data, heuristic = true, threads = 16, time_limit = 3600)
#write_log(logger,"log")

line_indicators = [true for i in 1:length(data.lines)]
dual_indicators = [true for i in 1:length(data.lines)]
constraint_indicators = [true for i in 1:length(data.lines)]
dual_probe = [false for i in 1:length(data.lines)]

runtime, status, objective, solution, a1, a2 = solve_TS_LP_Duals(grb_env, data, line_indicators, threads = 16)
duals = Array{Float64, 1}(undef, length(data.lines))
for i in 1:length(data.lines)
    if line_indicators[i]
        duals[i] = a1[i]
    else
        duals[i] = a2[i]
    end
end

line_idxs = sortperm(duals, rev = false)

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

plist = get_priority_list(line_idxs, 1,150)

for i in 1:length(plist)
        constraint_indicators[plist[i]] = false
end

mipstart = [true for i in 1:length(data.lines)]

solve_TS_MIP_Deco(grb_env, data, line_indicators, constraint_indicators, false, mipstart, uplink = false, threads = 16, time_limit = 50)

runtime, status, objective, solution, a1, a2 = solve_TS_LP_Duals(grb_env, data, mipstart, threads = 16)
duals = zeros(length(data.lines))
for i in 1:length(data.lines)
    if mipstart[i]
        duals[i] = a1[i]
    else
        duals[i] = a2[i]
    end
end

line_idxs = sortperm(duals, rev = true)

plist = get_priority_list(line_idxs, 1,220)

constraint_indicators = [true for i in 1:length(data.lines)]
for i in 1:length(plist)
        constraint_indicators[plist[i]] = false
end

solve_TS_MIP_Deco(grb_env, data, line_indicators, constraint_indicators, false, mipstart, uplink = false, threads = 16, time_limit = 50)


value(switched[550])

solve_TS_MIP(data, threads = 4)



THETAMAX = 0.6

THETAMIN = -0.6
line_indicators = [true for i in 1:length(data.lines)]
constraint_indicators = [true for i in 1:length(data.lines)]
d = solve_TS_LP_RLX(env, data, line_indicators)
m = d[6]
t = m.moi_backend.model_to_optimizer_map

m = Model()

@variable(m, t[1:2] >= 0)

@objective(m, Min, t[1] + t[2])

a = JuMP.variable_by_name(m, "t[1]")
typeof(a)

optimize!(m, with_optimizer(Gurobi.Optimizer))

m.moi_backend.model_to_optimizer_map[index(t)].value
using MathOptInterface
m.moi_backend.optimizer_to_model_map[MathOptInterface.VariableIndex(2500)]

res = solve_TS_MILP_DEC(env, data, line_indicators, constraint_indicators, threads = 4, time_limit = 30)

line_indicators = [true for i in 1:length(data.lines)]

d = solve_TS_LP_RLX(env, data, line_indicators)


graph = PowerGrids.toGraph(data)

ST = PowerGrids.bfs(graph.Graph)

adjlst = PowerGrids.adjacency_list(ST)

#line_vector = PowerGrids.line_vector(adjlst, data, returnType = :bool)
line_indicators = [true for i in 1:length(data.lines)]
constraint_indicators = [true for i in 1:length(data.lines)]

PowerGrids.rmLines!(constraint_indicators, data, 200)

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
