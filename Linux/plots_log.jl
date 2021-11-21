using PyPlot
using CSV, DataFrames

cd(@__DIR__)

logname = "cases/1354/1354_log"

hrstc = false

data = CSV.read(string(logname,".txt"), DataFrame)

lbs = data[:lb][length(data[:lb])]

fig = figure(figsize=(8, 3))
rc("font",family="serif",style="italic")
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

color1 = ""

ax = fig.add_axes([0.071,0.18,0.916,0.70])
ax.tick_params(direction="in",top=true,right=true,width=1.4)

# for (i,value) in enumerate(keys(ax.spines))
#         ax.spines[value].set_linewidth(1.4)
# end

#title(string(name,", heuristics"),weight="bold",family="non-serif",style="normal")

grid(color="lightblue",linewidth=0.4)
#yscale("log")
#xlim(left=0,right=maximum(x_lb)+10)
xlabel("Time \$[s]\$")

ylim(bottom=-0.4,top=1.9)
#ylabel("\$100\\left(\\frac{x}{lb*}-1\\right)\$")
ylabel("\$lb^{*}\$ gap \$[\\%]\$")

plot(data[:time],(data[:ub] ./ lbs .- 1) * 100,color="black",linestyle="dotted",label="P-OTSP, up")
plot(data[:time],(data[:lb] ./ lbs .- 1) * 100,color="black",linestyle="dashed",label="P-OTSP, lb")

init0 = false
init1 = false
for i in 1:length(data[:lb])
        if data[:src][i] == 1.0
                if !init1
                        plot(data[:time][i],(data[:ub][i] ./ lbs .- 1) * 100,lw = 0.0,mfc = "green",ms = 3.5,marker="D",mew=0.0,label="P-OTSP, sol., rank 1")
                        global init1 = true
                else
                        plot(data[:time][i],(data[:ub][i] ./ lbs .- 1) * 100,mfc = "green",ms = 3.5,marker="D",mew=0.0)
                end
        else
                if !init0
                        plot(data[:time][i],(data[:ub][i] ./ lbs .- 1) * 100,lw = 0.0,mfc = "darkblue",ms = 3.5,marker="s",mew=0.0,label="P-OTSP, sol., rank 0")
                        global init0 = true
                else
                        plot(data[:time][i],(data[:ub][i] ./ lbs .- 1) * 100,mfc = "darkblue",ms = 3.5,marker="s",mew=0.0)
                end
        end
end

legend(loc = "upper right",fancybox=false,edgecolor="black")
savefig(string("",logname,".pdf"), format = :pdf)
