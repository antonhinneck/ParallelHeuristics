using PyPlot
# NOTEBOOK i7-6500U 2 cores, 4 threads
name = "pglib_opf_case2848_rte"

x1 = ([0,180])
y1 = ([0,0])

fig = figure(figsize=(8, 3))
rc("font",family="serif",style="italic",size=12)
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

ax = fig.add_axes([0.071,0.18,0.916,0.70])
ax.tick_params(direction="in",top=true,right=true,width=1.4)

for (i,value) in enumerate(keys(ax.spines))
        ax.spines[value].set_linewidth(1.4)
end

title(string(name,", no heuristics"),weight="bold",family="non-serif",style="normal")

grid(color="lightblue",linewidth=0.4)

xlim(left=0,right=maximum(x1)+0.5)
xlabel("Time \$[s]\$")

ylim(bottom=-2.5,top=2.5)
#ylabel("\$100\\left(\\frac{x}{lb*}-1\\right)\$")
ylabel("\$lb^{*}\$ gap \$[\\%]\$")

plot(x1,y1,color="black",linestyle="dotted",label="Lower bound, root process")
legend(loc = "upper right",fancybox=false,edgecolor="black")

savefig("plots\\pglib_opf_case2848_rte.pdf", format = :pdf)

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

lb = 1045576.4251
sols = [1045576.4251]

x1 = [0,9.21]
y1 = [0,0]

x2 = [9.21]
y2 = [0]


fig = figure(figsize=(8, 3))
rc("font",family="serif",style="italic")
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

ax = fig.add_axes([0.071,0.18,0.916,0.70])
ax.tick_params(direction="in",top=true,right=true,width=1.4)

for (i,value) in enumerate(keys(ax.spines))
        ax.spines[value].set_linewidth(1.4)
end

title(string(name,", heuristics"),weight="bold",family="non-serif",style="normal")

grid(color="lightblue",linewidth=0.4)

xlim(left=0,right=maximum(x1)+0.5)
xlabel("Time \$[s]\$")

ylim(bottom=-2.5,top=2.5)
#ylabel("\$100\\left(\\frac{x}{lb*}-1\\right)\$")
ylabel("\$lb^{*}\$ gap \$[\\%]\$")

plot(x1,y1,color="black",linestyle="dotted",label="Lower bound, root process")
plot(x2,y2,markerfacecolor="black",marker="s",ms=6,mew=0,linewidth=0,label="Heuristic solutions, worker process")
legend(loc = "upper right",fancybox=false,edgecolor="black")

savefig("plots\\pglib_opf_case2848_rte_hrstc.pdf", format = :pdf)
