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

name = "pglib_opf_case1354_pegase"

x = [0,1,1,140]
y = [1097782.23,1100241.64,1101003.08,1101003.08]

x1, y1 = step(x,dist(y, maximum(y)))

fig = figure(figsize=(8, 3))
rc("font",family="serif",style="italic",size=12)
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

ax = fig.add_axes([0.09,0.18,0.9,0.70])
ax.tick_params(direction="in",top=true,right=true,width=1.4)

for (i,value) in enumerate(keys(ax.spines))
        ax.spines[value].set_linewidth(1.4)
end

title(string(name,", no heuristics"),weight="bold",family="non-serif",style="normal")

grid(color="lightblue",linewidth=0.4)

xlim(left=0,right=maximum(x1)+5)
xlabel("Time \$[s]\$")

ylim(bottom=-0.31,top=0.1)
#ylabel("\$100\\left(\\frac{x}{lb*}-1\\right)\$")
ylabel("\$lb^{*}\$ gap \$[\\%]\$")

plot(x1,y1,color="black",linestyle="dotted",label="Lower bound, root process")
legend(loc = "upper right",fancybox=false,edgecolor="black")

savefig("plots\\pglib_opf_case1354_pegase.pdf", format = :pdf)

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

x = [2,2,2,140]
y = [1097782.23,1100241.64,1101003.08,1101003.08]

xg = [52]
yg = [1.1215557699]

xs = [5,52,52,52,52,52,52,52,52,70,70,70,70,70,70,70,70,70,70,113,113,113,113,113,113,113,113,113,113]
ys = [1.1217086931299008,1.1104535685866296, 1.110454576707667,1.1104803956740631,1.110512207072236,1.1157072577219778,1.1157083426947435,1.1170838034795132,1.1698916791070607,1.1206486286003366,1.1206486555417508,1.1206508780061714,1.1207915714001579,1.1207916085378756,1.1207922332719774,1.1209292528738976,1.1209295454691278,1.1212348595718937,1.1231363711355918,1.1206563566886955,1.1206566287885858,1.120668834375139,1.1206688346727795,1.12072462536969,1.121016208974021,1.1210340517791419,1.1210340550862711,1.1213227573585245,1.1213262707189778]

xi = [5,52,52,140]
yi = [1.1217086931299008,1.1215557699,1.1104535685866296,1.1104535685866296]

x1, y1 = step(x,dist(y, maximum(y)))
xs1, ys1 = xs, dist(ys*1000000, maximum(y))
xi1, yi1 = xi, dist(yi*1000000, maximum(y))
xg1, yg1 = xg, dist(yg*1000000, maximum(y))

fig = figure(figsize=(8, 3.4))
rc("font",family="serif",style="italic")
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

ax = fig.add_axes([0.052,0.125,0.94,0.8])
#ax.set_yscale("log")
ax.tick_params(direction="in",top=true,right=true,width=1.4)

for (i,value) in enumerate(keys(ax.spines))
        ax.spines[value].set_linewidth(1.4)
end

title(string(name,", heuristics"),weight="bold",family="non-serif",style="normal")

grid(color="lightblue",linewidth=0.4)

xlim(left=0,right=maximum(x1)+5)
xlabel("Time \$[s]\$")

#ylim(bottom=-0.4,top=3.5)
#ylabel("\$100\\left(\\frac{x}{lb*}-1\\right)\$")
ylabel("\$lb^{*}\$ gap \$[\\%]\$")

plot(x1,y1,color="black",linestyle="dotted",label="Lower bound, root process")
plot(xi1,yi1,color="black",linestyle="dashed",label="Incumbent solution, root process")
plot(xs1,ys1,markerfacecolor="black",marker="s",ms=6,mew=0,linewidth=0,label="Heuristic solutions, worker process")
plot(xg1,yg1,markerfacecolor="black",marker="D",ms=6,mew=0,linewidth=0,label="Gurobi's solutions, root process")
legend(loc = "upper right",fancybox=false,edgecolor="black")

savefig("plots\\pglib_opf_case1354_pegase_hrstc.pdf", format = :pdf)
