# using Dates
# using MPI, Gurobi, JuMP
# using Gurobi: _CallbackUserData, CallbackData
# using MathOptInterface: TerminationStatusCode, VariableIndex
# using Base: time
# using Base: cconvert, unsafe_convert, broadcastable
# using Dates
# include("/home/antonhinneck/projects/github/PowerGrids.jl/src/PowerGrids.jl")

# include("utils/misc_utils.jl")
# include("utils/grb_utils.jl")
# include("utils/debug_utils.jl")
# include("utils/mpi_utils.jl")
# include("models/_otsp.jl")
# include("models/_rotsp.jl")
# include("models/_stdcopf.jl")

# cd(@__DIR__)

# const THETAMAX = 1.2
# const THETAMIN = -1.2

# grb_env = Gurobi.Env()
# n_vals = [40 * i for i in 1:5]

# PowerGrids.set_csv_path("/home/antonhinneck/projects/github/pglib2csv/pglib/2020-08-21.19-54-30-275/csv")
# PowerGrids.csv_cases(verbose = true)
# PowerGrids.select_csv_case(4)
# data = PowerGrids.loadCase()

# ROOT = 0
# Iea = [true for i in 1:length(data.lines)]
# m_opf = build_stdcopf(grb_env, data, Iea = Iea, threads = 8)
# optimize!(m_opf)

# # get_sensitivities_lpsc
# # Price difference switching criterion
# # get_sensitivities_pdsc
# # Total cost difference switching criterion
# # get_sensitivities_tcdsc
# # PTDF-Weighted cost derivative criterion: DONE
# # get_sensitivities_pwsc

# switching_criterion = PowerGrids.get_sensitivities_pwsc
# objective = objective_value(m_opf)
# sc_vals = switching_criterion(data, m_opf)
# dp = sortperm(sc_vals, rev = true)

# for n in n_vals
#     Ies = [false for i in 1:length(data.lines)]
#     for i in 1:n
#         Ies[dp[i]] = true
#     end
#     logger, root_inc, tstat = solve_rotsp(grb_env, data, Iea, Ies, [false], [Inf64, ones(length(data.lines))...], threads = 8, outputflag = 1, time_limit = 60, mipgap = 10e-5, logger_active = true)
#     write_log(logger,string("logs_sensitivity/",data.name,"_",n,"_pwsc"))
# end

using PyPlot, CSV, DataFrames

logname = data.name

data11 =  CSV.read(string("logs_sensitivity/",logname,"_40_lpsc",".txt"), DataFrame)
data12 =  CSV.read(string("logs_sensitivity/",logname,"_80_lpsc",".txt"), DataFrame)
data13 =  CSV.read(string("logs_sensitivity/",logname,"_120_lpsc",".txt"), DataFrame)
data14 =  CSV.read(string("logs_sensitivity/",logname,"_160_lpsc",".txt"), DataFrame)
data15 =  CSV.read(string("logs_sensitivity/",logname,"_200_lpsc",".txt"), DataFrame)

data21 =  CSV.read(string("logs_sensitivity/",logname,"_40_pdsc",".txt"), DataFrame)
data22 =  CSV.read(string("logs_sensitivity/",logname,"_80_pdsc",".txt"), DataFrame)
data23 =  CSV.read(string("logs_sensitivity/",logname,"_120_pdsc",".txt"), DataFrame)
data24 =  CSV.read(string("logs_sensitivity/",logname,"_160_pdsc",".txt"), DataFrame)
data25 =  CSV.read(string("logs_sensitivity/",logname,"_200_pdsc",".txt"), DataFrame)

data31 =  CSV.read(string("logs_sensitivity/",logname,"_40_tcdsc",".txt"), DataFrame)
data32 =  CSV.read(string("logs_sensitivity/",logname,"_80_tcdsc",".txt"), DataFrame)
data33 =  CSV.read(string("logs_sensitivity/",logname,"_120_tcdsc",".txt"), DataFrame)
data34 =  CSV.read(string("logs_sensitivity/",logname,"_160_tcdsc",".txt"), DataFrame)
data35 =  CSV.read(string("logs_sensitivity/",logname,"_200_tcdsc",".txt"), DataFrame)

data41 =  CSV.read(string("logs_sensitivity/",logname,"_40_pwsc",".txt"), DataFrame)
data42 =  CSV.read(string("logs_sensitivity/",logname,"_80_pwsc",".txt"), DataFrame)
data43 =  CSV.read(string("logs_sensitivity/",logname,"_120_pwsc",".txt"), DataFrame)
data44 =  CSV.read(string("logs_sensitivity/",logname,"_160_pwsc",".txt"), DataFrame)
data45 =  CSV.read(string("logs_sensitivity/",logname,"_200_pwsc",".txt"), DataFrame)

lbs = 1.1010030841758288e6

fig = figure(figsize=(4, 4))
rc("font",family="serif",style="italic",size=15.8)
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

ax = fig.add_axes([0.13,0.13,0.86,0.86])
ax.tick_params(direction="in",top=true,right=true,width=1.4)

grid(color="lightgray",linewidth=1.0, ls = "dashed")
xlabel("Time \$[s]\$")
xscale("log")

for axis in ["top", "bottom", "left", "right"]
        ax.spines[axis].set_linewidth(0.0)
end

ylim(bottom=-0.4,top=3.9)
ylabel("gap \$[\\%]\$")

plot(data11[:time],(data11[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "skyblue",color="skyblue",ms = 3.0,marker="D",mew=0.0,label="n=40")
plot(data12[:time],(data12[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "blue",color="blue",ms = 3.0,marker="D",mew=0.0,label="n=80")
plot(data13[:time],(data13[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "darkblue",color="darkblue",ms = 3.0,marker="D",mew=0.0,label="n=120")
plot(data14[:time],(data14[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "lightgreen",color="lightgreen",ms = 3.0,marker="D",mew=0.0,label="n=160")
plot(data15[:time],(data15[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "green",color="green",ms = 3.0,marker="D",mew=0.0,label="n=200")

legend(loc = "upper right",fancybox=false,edgecolor="black", ncol = 2)
savefig(string("plots/","sensitivity1",".pdf"), format = :pdf)

fig = figure(figsize=(4, 4))
rc("font",family="serif",style="italic",size=15.8)
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

ax = fig.add_axes([0.13,0.13,0.86,0.86])
ax.tick_params(direction="in",top=true,right=true,width=1.4)

grid(color="lightgray",linewidth=1.0, ls = "dashed")
xlabel("Time \$[s]\$")
xscale("log")

for axis in ["top", "bottom", "left", "right"]
        ax.spines[axis].set_linewidth(0.0)
end

ylim(bottom=-0.4,top=3.9)
ylabel("gap \$[\\%]\$")

plot(data21[:time],(data21[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "skyblue",color="skyblue",ms = 3.0,marker="D",mew=0.0,label="n=40")
plot(data22[:time],(data22[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "blue",color="blue",ms = 3.0,marker="D",mew=0.0,label="n=80")
plot(data23[:time],(data23[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "darkblue",color="darkblue",ms = 3.0,marker="D",mew=0.0,label="n=120")
plot(data24[:time],(data24[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "lightgreen",color="lightgreen",ms = 3.0,marker="D",mew=0.0,label="n=160")
plot(data25[:time],(data25[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "green",color="green",ms = 3.0,marker="D",mew=0.0,label="n=200")

legend(loc = "upper right",fancybox=false,edgecolor="black", ncol = 2)
savefig(string("plots/","sensitivity2",".pdf"), format = :pdf)

fig = figure(figsize=(4, 4))
rc("font",family="serif",style="italic",size=15.8)
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

ax = fig.add_axes([0.13,0.13,0.86,0.86])
ax.tick_params(direction="in",top=true,right=true,width=1.4)

grid(color="lightgray",linewidth=1.0, ls = "dashed")
xlabel("Time \$[s]\$")
xscale("log")

for axis in ["top", "bottom", "left", "right"]
        ax.spines[axis].set_linewidth(0.0)
end

ylim(bottom=-0.4,top=3.9)
ylabel("gap \$[\\%]\$")

plot(data31[:time],(data31[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "skyblue",color="skyblue",ms = 3.0,marker="D",mew=0.0,label="n=40")
plot(data32[:time],(data32[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "blue",color="blue",ms = 3.0,marker="D",mew=0.0,label="n=80")
plot(data33[:time],(data33[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "darkblue",color="darkblue",ms = 3.0,marker="D",mew=0.0,label="n=120")
plot(data34[:time],(data34[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "lightgreen",color="lightgreen",ms = 3.0,marker="D",mew=0.0,label="n=160")
plot(data35[:time],(data35[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "green",color="green",ms = 3.0,marker="D",mew=0.0,label="n=200")

legend(loc = "upper right",fancybox=false,edgecolor="black", ncol = 2)
savefig(string("plots/","sensitivity3",".pdf"), format = :pdf)

fig = figure(figsize=(4, 4))
rc("font",family="serif",style="italic",size=15.8)
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

ax = fig.add_axes([0.13,0.13,0.86,0.86])
ax.tick_params(direction="in",top=true,right=true,width=1.4)

grid(color="lightgray",linewidth=1.0, ls = "dashed")
xlabel("Time \$[s]\$")
xscale("log")

for axis in ["top", "bottom", "left", "right"]
        ax.spines[axis].set_linewidth(0.0)
end

ylim(bottom=-0.4,top=3.9)
ylabel("gap \$[\\%]\$")

plot(data41[:time],(data41[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "skyblue",color="skyblue",ms = 3.0,marker="D",mew=0.0,label="n=40")
plot(data42[:time],(data42[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "blue",color="blue",ms = 3.0,marker="D",mew=0.0,label="n=80")
plot(data43[:time],(data43[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "darkblue",color="darkblue",ms = 3.0,marker="D",mew=0.0,label="n=120")
plot(data44[:time],(data44[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "lightgreen",color="lightgreen",ms = 3.0,marker="D",mew=0.0,label="n=160")
plot(data45[:time],(data45[:ub] ./ lbs .- 1) * 100,lw = 1.8,linestyle="solid",mfc = "green",color="green",ms = 3.0,marker="D",mew=0.0,label="n=200")

legend(loc = "upper right",fancybox=false,edgecolor="black", ncol = 2)
savefig(string("plots/","sensitivity4",".pdf"), format = :pdf)