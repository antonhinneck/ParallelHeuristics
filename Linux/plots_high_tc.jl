using PyPlot
using CSV, DataFrames

cd(@__DIR__)
logname_1 = "logs/pglib_opf_case1354_pegase_log_s"
logname_2 = "logs/pglib_opf_case1354_pegase_log_p"
logname_3 = "logs_high_tc/pglib_opf_case1354_pegase_tc3_log_p"
logname_4 = "logs_high_tc/pglib_opf_case1354_pegase_tc4_log_p"
ns = true
case3012 = false
case6470 = false
case3120 = false
u = 1.9

hrstc = false
data1 = CSV.read(string(logname_1,".txt"), DataFrame)
data2 = CSV.read(string(logname_2,".txt"), DataFrame)
data3 = CSV.read(string(logname_3,".txt"), DataFrame)
data4 = CSV.read(string(logname_4,".txt"), DataFrame)

s_1 = data1[:ub][length(data1[:ub])]
s_2 = data2[:ub][length(data2[:ub])]
s_3 = data3[:ub][length(data3[:ub])]
s_4 = data4[:ub][length(data4[:ub])]
lbs = data2[:lb][length(data2[:lb])]

fig = figure(figsize=(5, 2))
rc("text", usetex = true)
rc("text.latex", preamble = "\\usepackage{amsmath}\\usepackage{calrsfs}")
rc("font",family="serif",style="italic", size = 11)
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

ax = fig.add_axes([0.12,0.19,0.87,0.78])

ax.tick_params(direction="in",top=true,right=true,width=1.4)
grid(color="lightgray",linewidth=1.0, ls = "dashed")
xlabel("Time \$[s]\$")
xscale("log")
yscale("log")

for axis in ["top", "bottom", "left", "right"]
        ax.spines[axis].set_linewidth(0.0)
end

ylim(bottom = 0.001, top=5.1)
ylabel("gap \$[\\%]\$")

plot(data1[:time],(data1[:ub] ./ lbs .- 1) * 100,color="black",linestyle="dashed",mfc = "black",ms = 3.0,marker="s",mew=0.0,label="OTSP\$_{\\boldsymbol{x0}}\$")
plot(data2[:time],(data2[:ub] ./ lbs .- 1) * 100,color="darkblue",linestyle="dashed",mfc = "darkblue",ms = 3.0,marker="s",mew=0.0,label="P-OTSP, \$\\lvert\\mathcal{J}\\rvert=1\$")
plot(data3[:time],(data3[:ub] ./ lbs .- 1) * 100,color="orange",linestyle="dashed",mfc = "orange",ms = 3.0,marker="s",mew=0.0,label="P-OTSP, \$\\lvert\\mathcal{J}\\rvert=2\$")
plot(data4[:time],(data4[:ub] ./ lbs .- 1) * 100,color="red",linestyle="dashed",mfc = "red",ms = 3.0,marker="s",mew=0.0,label="P-OTSP, \$\\lvert\\mathcal{J}\\rvert=3\$")

legend(loc = "lower left",fancybox=false,edgecolor="black", ncol = 1)
savefig(string("plots_updt/comparison_thread_counts.pdf"), format = :pdf)
