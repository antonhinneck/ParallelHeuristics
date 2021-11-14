using MPI, Gurobi, JuMP
using MathOptInterface: TerminationStatusCode
using MathOptInterface#: TerminationStatusCode
using Base: time
cd(@__DIR__)

include("C:/Users/Anton Hinneck/juliaPackages/GitHub/PowerGrids.jl/src/PowerGrids.jl")

include("Model_MIP_DecompositionS.jl")
include("Model_LP_Duals.jl")
include("functions.jl")

grb_env = Gurobi.Env()

logs = Vector{Logger}()

datasources = PowerGrids.datasets()
data = PowerGrids.readDataset(datasources[3])

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

n = [10, 20, 60, 100, 140, 160, 180]
d = [10, 20, 40]

line_indicators = [true for l in data.lines]
runtime, status, objective, solution, a1, a2 = solve_TS_LP_Duals(grb_env, data, line_indicators, threads = 4)

duals = Array{Float64, 1}(undef, length(data.lines))
for i in 1:length(data.lines)
    if line_indicators[i]
        duals[i] = a1[i]
    else
        duals[i] = a2[i]
    end
end

line_idxs = deepcopy(data.lines)
line_idxs = sortperm(duals)
ctr = 1
for n in [10, 20, 60, 100, 140, 160, 180]
    push!(logs, Logger(0, Vector{Float64}(), Vector{Float64}(), Vector{Float64}(), Vector{Float64}()))
    plist = get_priority_list(line_idxs, 0, n)
    constraint_indicators = [true for i in 1:length(data.lines)]
    optimizer_terminated = false
    mipstart = [true for i in 1:length(data.lines)]
    for i in 1:length(plist)
            constraint_indicators[plist[i]] = false
    end
    root_inc, tstat = solve_TS_MIP_DecoS(grb_env, data, line_indicators, constraint_indicators, optimizer_terminated, mipstart, threads = 16, time_limit = 60)
    global ctr += 1
end

lb = logs[7].objbnd[16]
using PyPlot
using Colors
cd(@__DIR__)
include("gradients.jl")

#c1 = RGBA(50 / 255, 205 / 255, 50 / 255, 1)
c1 = RGBA(236 / 255, 229 / 255, 27 / 255, 1)
c2 = RGBA(72 / 255, 28 / 255, 110 / 255, 1)
grads = gradient(c1, c2, length(logs))

fig = figure(figsize=(6.8, 2.8))
rc("font",family="serif",style="italic", size = 12)
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

ax = fig.add_axes([0.125, 0.175, 0.87, 0.8])

ax.spines["top"].set_visible(false)
ax.spines["right"].set_visible(false)

xlim(left = 0, right = 74)

xlabel("Time \$[s]\$")
ylabel("gap \$[\\%]\$")

ctr = 1
for i in n
    plot([0.0, logs[ctr].time...], [1121708.69, logs[ctr].bstobj...] / lb, color = [grads[1][ctr].r, grads[1][ctr].g, grads[1][ctr].b], linestyle = "dashed", lw = 0.8, label = string(n[ctr]), marker = "D", ms = 1.2)
    global ctr += 1
end

leg = legend(loc = "upper right", framealpha = 0.4, fancybox = false, edgecolor = "black", title = "\$ n^{S}\$")
leg.get_frame().set_linewidth(0.5)
fig.tight_layout()

name = "n_sensitivity"
savefig(string("plots\\",name,".pdf"), format = :pdf)
