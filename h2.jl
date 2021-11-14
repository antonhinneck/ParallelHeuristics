using JuMP, Gurobi, Gadfly, DataStructures
using MathOptInterface ## Cbc, GLPK, HTTP, JSON
include("C:/Users/Anton Hinneck/.julia/packages/PowerGrids/src/PowerGrids.jl")

include("Model_flow.jl")
include("Model_switching.jl")
include("Model_flow_cb.jl")
include("Model_flow_search.jl")

src = 29
datasources = PowerGrids.datasets()

print("\n", datasources[src], "\n")
data = PowerGrids.readDataset(datasources[src])

graph = PowerGrids.toGraph(data).Graph

function initial_relaxation(data, entries)

    pf = solve_TS_LP(data)
    print("\n", length(pf), "\n")
    dict = Dict{Int16, Float64}()

    for i in 1:length(data.lines)
        push!(dict, data.lines[i] => abs(pf[i]))
    end

    sd = SortedDict(dict)
    vals = [values(sd)...]
    kys  = [keys(sd)...]

    return kys[1:entries]
end

lns = initial_relaxation(data, 3400)

solve_TS_MILP(data)

ts = MathOptInterface.TerminationStatusCode(2)
count = 0
while ts != MathOptInterface.TerminationStatusCode(1) && count < 5
    st = PowerGrids.bfs(graph, initialization = :rnd)
    adjlst = PowerGrids.adjacency_list(st)
    lv = PowerGrids.line_vector(adjlst, data)

    for i in 1:length(lns)
        if !(lns[i] in Set(lv))
            push!(lv, lns[i])
        end
    end

    global ts = solve_TS_LP_Search(data, lv)
    global count += 1
end
#line_vector = PowerGrids.line_vector(PowerGrids.adjacency_list(PowerGrids.paton(, initialization = :rnd)[2]), data)
