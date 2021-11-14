using PyPlot
using CSV

#name = "log_1354_logger_no_hrstc"
#name = "log_1888_rte_logger_no_hrstc"
#name = "log_1888_rte_logger"
#name = "log_1999_rte_logger"
name = "log_1999_rte_logger_no_hrstc"

hrstc = false

data = CSV.read(string("logs\\",name,".txt"))

inc = Vector{Float64}()
lb = Vector{Float64}()
rank = Vector{Float64}()
time = Vector{Float64}()
time_inc = Vector{Float64}()
time = Vector{Float64}()

lbs = maximum(data[:lb][:])

for (i, value) in enumerate(data[:incumbent][:])
        new_inc = 100 * (value - lbs) / lbs
        if new_inc < 2000.0
                push!(inc, new_inc)
                push!(time_inc, data[:time][i])
        end
end

for (i, value) in enumerate(data[:lb][:])
        new_lb = 100 * (value - lbs) / lbs
        push!(lb, new_lb)
end

for (i, value) in enumerate(data[:time][:])
        push!(time, value)
        push!(rank, data[:rank][:][i])
end

x_lb = Vector{Float64}()
y_lb = Vector{Float64}()
x_inc = Vector{Float64}()
y_inc = Vector{Float64}()
x_inc_r1 = Vector{Float64}()
y_inc_r1 = Vector{Float64}()

cinc = 0
for i in 1:length(inc)
        if i == 1
                push!(x_inc, time_inc[i])
                push!(y_inc, inc[i])
                global cinc += 1
        end
        if i == length(inc)
                push!(x_inc, time_inc[i])
                push!(y_inc, inc[i])
        end
        if i > 1 && i < length(lb)
                if y_inc[cinc] > inc[i]
                        push!(x_inc, time_inc[i])
                        push!(y_inc, y_inc[cinc])
                        push!(x_inc, time_inc[i])
                        push!(y_inc, inc[i])
                        global cinc += 2
                end
        end
end

clb = 0
for i in 1:length(lb)
        if i == 1
                push!(x_lb, time[i])
                push!(y_lb, lb[i])
                global clb += 1
        end
        if i == length(lb)
                push!(x_lb, time[i])
                push!(y_lb, lb[i])
        end
        if i > 1 && i < length(lb)
                if y_lb[clb] < lb[i]
                        push!(x_lb, time[i])
                        push!(y_lb, y_lb[clb])
                        push!(x_lb, time[i])
                        push!(y_lb, lb[i])
                        global clb += 2
                end
        end
end

for (i,value) in enumerate(data[:incumbent][:])
        if rank[i] == 1.0
                push!(x_inc_r1, time[i])
                push!(y_inc_r1, 100 * (value - lbs) / lbs)
        end
end

fig = figure(figsize=(8, 3))
rc("font",family="serif",style="italic")
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

ax = fig.add_axes([0.071,0.18,0.916,0.70])
ax.tick_params(direction="in",top=true,right=true,width=1.4)

for (i,value) in enumerate(keys(ax.spines))
        ax.spines[value].set_linewidth(1.4)
end

#title(string(name,", heuristics"),weight="bold",family="non-serif",style="normal")

grid(color="lightblue",linewidth=0.4)

xlim(left=0,right=maximum(x_lb)+10)
xlabel("Time \$[s]\$")

ylim(bottom=-2.5,top=2.5)
#ylabel("\$100\\left(\\frac{x}{lb*}-1\\right)\$")
ylabel("\$lb^{*}\$ gap \$[\\%]\$")

plot(x_lb,y_lb,color="black",linestyle="dotted",label="Lower bound, root process")
plot(x_inc,y_inc,color="black",linestyle="solid",label="Incumbent solution, root process")
if hrstc
        plot(x_inc_r1,y_inc_r1,markerfacecolor="black",marker="s",ms=4.2,mew=0,linewidth=0,label="Heuristic solutions, worker process")
end
legend(loc = "upper right",fancybox=false,edgecolor="black")

savefig(string("plots\\",name,".pdf"), format = :pdf)
