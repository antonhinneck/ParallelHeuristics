using PyPlot
using CSV, DataFrames

cd(@__DIR__)

logname_p = "pglib_opf_case1354_pegase_log_p"
logname_s = "pglib_opf_case1354_pegase_log_s"
logname_ns = "pglib_opf_case1354_pegase_log_ns"
logname_itrs = "pglib_opf_case1354_pegase_iterations"

# logname_p = "pglib_opf_case588_sdet_log_p"
# logname_s = "pglib_opf_case588_sdet_log_s"
# logname_ns = "pglib_opf_case588_sdet_log_ns"
# logname_itrs = "pglib_opf_case588_sdet_iterations"

# logname_p = "pglib_opf_case588_sdet_log_p"
# logname_s = "pglib_opf_case588_sdet_log_s"
# logname_ns = "pglib_opf_case588_sdet_log_ns"
# logname_itrs = "pglib_opf_case588_sdet_iterations"

hrstc = false

data = CSV.read(string("logs/",logname_p,".txt"), DataFrame)
data2 = CSV.read(string("logs_updt/",logname_s,".txt"), DataFrame)
data3 = CSV.read(string("logs/",logname_ns,".txt"), DataFrame)
data4 = CSV.read(string("logs/",logname_itrs,".txt"), DataFrame)

lbs = data[:lb][length(data[:lb])]

fig = figure(figsize=(8, 2.0))
rc("font",family="serif",style="italic", size=10)
rc("text", usetex = true)
rc("text.latex", preamble = "\\usepackage{amsmath}\\usepackage{calrsfs}")
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

ax = fig.add_axes([0.045,0.19,0.945,0.8])
ax.tick_params(direction="in",top=true,right=true,width=1.4)

grid(color="lightgray",linewidth=1.0, ls = "dashed")
xlabel("Time \$[s]\$")
xscale("log")

for axis in ["top", "bottom", "left", "right"]
        ax.spines[axis].set_linewidth(0.0)
end

ylim(bottom=-0.4,top=3.9)
#\$lb^{*}\$
ylabel("gap \$[\\%]\$")
#\$_{\\boldsymbol{x0}}\$

init = true
for i in data4[:time]
        if init 
                axvline(x=i, color = "skyblue", ls = "solid", label = "P-OTSP, itr., r.1")
        else
                axvline(x=i, color = "skyblue", ls = "solid")
        end
        init = false
end

plot(data2[:time],(data2[:ub] ./ lbs .- 1) * 100,color="gray",linestyle="dotted",mfc = "red",ms = 4.0,marker="s",mew=0.0,label="OTSP\$_{\\boldsymbol{x0}}\$")
plot(data3[:time],(data3[:ub] ./ lbs .- 1) * 100,color="gray",linestyle="dotted",mfc = "orange",ms = 4.0,marker="s",mew=0.0,label="OTSP")

plot(data[:time],(data[:ub] ./ lbs .- 1) * 100,color="black",linestyle="dotted",label="P-OTSP, ub")
plot(data[:time],(data[:lb] ./ lbs .- 1) * 100,color="black",linestyle="dashed",label="P-OTSP, lb")

init0 = false
init1 = false
for i in 1:length(data[:lb])
        if data[:src][i] == 1.0
                if !init1
                        plot(data[:time][i],(data[:ub][i] ./ lbs .- 1) * 100,lw = 0.0,mfc = "green",ms = 5.0,marker="D",mew=0.0,label="P-OTSP, sol., r.1")
                        global init1 = true
                else
                        plot(data[:time][i],(data[:ub][i] ./ lbs .- 1) * 100,mfc = "green",ms = 5.0,marker="D",mew=0.0)
                end
        else
                if !init0
                        plot(data[:time][i],(data[:ub][i] ./ lbs .- 1) * 100,lw = 0.0,mfc = "darkblue",ms = 3.0,marker="D",mew=0.0,label="P-OTSP, sol., r.0")
                        global init0 = true
                else
                        plot(data[:time][i],(data[:ub][i] ./ lbs .- 1) * 100,mfc = "darkblue",ms = 3.0,marker="D",mew=0.0)
                end
        end
end

legend(loc = "upper right",fancybox=false,edgecolor="black", ncol = 4)
savefig(string("plots_updt/",logname_p,".pdf"), format = :pdf)
