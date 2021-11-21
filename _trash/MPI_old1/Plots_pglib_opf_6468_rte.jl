using PyPlot
# NOTEBOOK i7-6500U 2 cores, 4 threads

function step(x::Array{T1,1} where T1 <: Number, y::Array{T2,1} where T2 <: Number)

        out_x = Vector{Float64}()
        out_y = Vector{Float64}()

        for i in 1:length(x)
                if i == 1
                        push!(out_x, x[i])
                        push!(out_y, y[i])
                else
                        push!(out_x, x[i])
                        push!(out_x, x[i])
                        push!(out_y, y[i-1])
                        push!(out_y, y[i])
                end
        end
        return out_x, out_y
end

function dist(y::Array{T1,1} where T1 <: Number, ref_val::T where T <: Number)

        output = Vector{Float64}()

        for i in 1:length(y)
                push!(output, (y[i]/ref_val-1)*100)
        end

        return output
end

name = "pglib_opf_case6468_rte"

x = [11,17,24,29,65,68,71,71,81,115,120, 240]
y = [1474908.37,1475295.58,1475306.89,1475308.78,1475318.00,1475319.20,1475320.37,1475334.32,1475335.07,1476450.85,1476616.70,1476616.70]


x1, y1 = step(x,dist(y, maximum(y)))

fig = figure(figsize=(8, 3))
rc("font",family="serif",style="italic",size=12)
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

ax = fig.add_axes([0.1,0.18,0.88,0.70])
ax.tick_params(direction="in",top=true,right=true,width=1.4)

for (i,value) in enumerate(keys(ax.spines))
        ax.spines[value].set_linewidth(1.4)
end

title(string(name,", no heuristics"),weight="bold",family="non-serif",style="normal")

grid(color="lightblue",linewidth=0.4)

xlim(left=0,right=maximum(x1)+5)
xlabel("Time \$[s]\$")

ylim(bottom=-0.125,top=0.05)
#ylabel("\$100\\left(\\frac{x}{lb*}-1\\right)\$")
ylabel("\$lb^{*}\$ Gap \$[\\%]\$")

plot(x1,y1,color="black",linestyle="dotted",label="Lower bound, root process")
legend(loc = "upper right",fancybox=false,edgecolor="black")

savefig("plots\\pglib_opf_case6468_rte.pdf", format = :pdf)

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

x = [12,19,26,32,65,69,71,72,86,125,130, 240]
y = [1474908.37,1475295.58,1475306.89,1475308.78,1475318.00,1475319.20,1475320.37,1475334.32,1475335.07,1475406.56,1476616.70,1476616.70]

xs = [71,71,71,71,71,71,122,122,122,122,160,160,160,207,207,207,207,207,207,224,224,224,224,224,240,240,240]
ys = [1.5613098201524825,1.5612881313195429,1.5612888275978642,1.561290648210746,1.56144089606036,1.5614434573095925,1.5594911905641607,1.559502360954617,1.5595032789396164,1.5598362650891761,1.560441746407944,1.5604469178383346,1.5606002213723585,1.561302791869741,1.56130280918008,1.5613028747761578,1.561515135198733,1.5615198315646637,1.56152208471133,1.5612970365236858,1.5612982556536463,1.5613086780073831,1.5613096406712004,1.5613369880125225,1.5613032839528732,1.5651639291237337,1.565250103974468]

xi = [71,71,122,122,240]
yi = [1561309.8202,1561288.1313,1561288.1313,1559491.1906,1559491.1906]

x1, y1 = step(x,dist(y, maximum(y)))
xs1, ys1 = xs, dist(ys*1000000, maximum(y))
xi1, yi1 = xi, dist(yi, maximum(y))

fig = figure(figsize=(8, 6))
rc("font",family="serif",style="italic")
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

ax = fig.add_axes([0.1,0.08,0.8,0.86])
#ax.set_yscale("log")
ax.tick_params(direction="in",top=true,right=true,width=1.4)

for (i,value) in enumerate(keys(ax.spines))
        ax.spines[value].set_linewidth(1.4)
end

title(string(name,", heuristics"),weight="bold",family="non-serif",style="normal")

grid(color="lightblue",linewidth=0.4)

xlim(left=0,right=maximum(x1)+5)
xlabel("Time \$[s]\$")

ylim(bottom=-0.2,top=6.2)
#ylabel("\$100\\left(\\frac{x}{lb*}-1\\right)\$")
ylabel("\$lb^{*}\$ Gap \$[\\%]\$")

plot(x1,y1,color="black",linestyle="dotted",label="Lower bound, root process")
plot(xi1,yi1,color="black",linestyle="dashed",label="Incumbent solution, root process")
plot(xs1,ys1,markerfacecolor="black",marker="s",ms=6,mew=0,linewidth=0,label="Heuristic solutions, worker process")
legend(loc = "center",fancybox=false,edgecolor="black")

savefig("plots\\pglib_opf_case6468_rte_hrstc.pdf", format = :pdf)
