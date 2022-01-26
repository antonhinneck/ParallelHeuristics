using PyPlot
using CSV, DataFrames

cd(@__DIR__)

# logname_p = "pglib_opf_case2746wop_k_log_p"
# logname_s = "pglib_opf_case2746wop_k_log_s"
# logname_ns = "pglib_opf_case2746wop_k_log_ns"
# ns = true
# case3012 = false
# case6470 = false
# case3120 = false
# u = 1.9
#legend(loc = "upper left",fancybox=false,edgecolor="black", ncol = 2)

# logname_p = "pglib_opf_case2736sp_k_log_p"
# logname_s = "pglib_opf_case2736sp_k_log_s"
# logname_ns = "pglib_opf_case2736sp_k_log_ns"
# ns = true
# case3012 = false
# case6470 = false
# case3120 = false
# u = 1.8

# logname_p = "pglib_opf_case2383wp_k_log_p"
# logname_s = "pglib_opf_case2383wp_k_log_s"
# logname_ns = "pglib_opf_case2383wp_k_log_ns"
# ns = false
# case3012 = false
# case6470 = false
# case3120 = false
# u = 4.9

# logname_p = "pglib_opf_case3012wp_k_log_p"
# logname_s = "pglib_opf_case3012wp_k_log_s"
# logname_ns = "pglib_opf_case3012wp_k_log_ns"
# ns = true
# case3012 = true
# case6470 = false
# case3120 = false
# u = 4.9

# logname_p = "pglib_opf_case3120sp_k_log_p"
# logname_s = "pglib_opf_case3120sp_k_log_s"
# logname_ns = "pglib_opf_case3120sp_k_log_ns"
# ns = true
# case3012 = false
# case3120 = true
# case6470 = false
# u = 4.9

# logname_p = "pglib_opf_case3375wp_k_log_p"
# logname_s = "pglib_opf_case3375wp_k_log_s"
# logname_ns = "pglib_opf_case3375wp_k_log_ns"
# ns = false
# case3012 = false
# case3120 = false
# case6470 = false
# u = 4.9

logname_p = "pglib_opf_case6470_rte_log_p"
logname_s = "pglib_opf_case6470_rte_log_s"
logname_ns = "pglib_opf_case6470_rte_log_ns"
ns = false
case3012 = false
case3120 = false
case6470 = true
u = 12.9

# logname_p = "pglib_opf_case13659_pegase_log_p"
# logname_s = "pglib_opf_case13659_pegase_log_s"
# logname_ns = "pglib_opf_case13659_pegase_log_ns"
# logname_htc = "pglib_opf_case13659_pegase_tc4_log_p"
# ns = false
# case3012 = false
# case3120 = false
# case6470 = false
# u = 1.5

hrstc = false

data = CSV.read(string("logs/",logname_p,".txt"), DataFrame)
data2 = CSV.read(string("logs_updt/",logname_s,".txt"), DataFrame)
data3 = CSV.read(string("logs/",logname_ns,".txt"), DataFrame)

s_init = data2[:ub][1]
s_p = data[:ub][length(data[:ub])]
s_s = data2[:ub][length(data2[:ub])]
s_ns = data3[:ub][length(data3[:ub])]
lbs = data[:lb][length(data[:lb])]

println(string("ns: ", 100 * (s_ns/lbs - 1)," ",100 * (s_init-s_ns)/s_init))
println(string("s: ", 100 * (s_s/lbs - 1)," ",100 * (s_init-s_s)/s_init))
println(string("p: ", 100 * (s_p/lbs - 1)," ",100 * (s_init-s_p)/s_init))

fig = figure(figsize=(5, 1.5))
rc("text", usetex = true)
rc("text.latex", preamble = "\\usepackage{amsmath}\\usepackage{calrsfs}")
rc("font",family="serif",style="italic", size = 10)
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

if case6470
        ax = fig.add_axes([0.0884,0.26,0.9,0.66])
else
        ax = fig.add_axes([0.071,0.26,0.916,0.66])
end

ax.tick_params(direction="in",top=true,right=true,width=1.4)
grid(color="lightgray",linewidth=1.0, ls = "dashed")
xlabel("Time \$[s]\$")
xscale("log")

for axis in ["top", "bottom", "left", "right"]
        ax.spines[axis].set_linewidth(0.0)
end

ylim(bottom=-0.4,top=u)
ylabel("gap \$[\\%]\$")

plot(data[:time],(data[:ub] ./ lbs .- 1) * 100,color="gray",linestyle="dotted",mfc = "darkblue",ms = 4.0,marker="s",mew=0.0,label="P-OTSP")
plot(data2[:time],(data2[:ub] ./ lbs .- 1) * 100,color="gray",linestyle="dotted",mfc = "orange",ms = 4.0,marker="s",mew=0.0,label="OTSP\$_{\\boldsymbol{x0}}\$")
if ns
        plot(data3[:time],(data3[:ub] ./ lbs .- 1) * 100,color="gray",linestyle="dotted",mfc = "green",ms = 4.0,marker="s",mew=0.0,label="OTSP")
end

if case6470
        legend(loc = "lower left",fancybox=false,edgecolor="black", ncol = 2) #6470
elseif case3120
        legend(loc = "lower left",fancybox=false,edgecolor="black", ncol = 3)
elseif case3012
        legend(loc = "upper left",fancybox=false,edgecolor="black", ncol = 2)
else
        legend(loc = "upper right",fancybox=false,edgecolor="black", ncol = 3)
end
savefig(string("plots_updt/",logname_p,".pdf"), format = :pdf)
