using PyPlot
using CSV


#name_ff = "log_1354_logger_no_hrstc"
#name = "log_1354_pegase_logger_run2"
name_ff = "log_1888_rte_logger_no_hrstc"
name = "log_1888_rte_logger"
#name = "log_1999_rte_logger"
#name_ff = "log_1999_rte_logger_no_hrstc"
#name = "log_1999_rte_logger"
#name_ff = "log_pglib_opf_case3120sp_k_logger_no_hrstc"
#name = "log_pglib_opf_case3120sp_k_logger"


data_ff = CSV.read(string("logs\\",name_ff,".txt"))
data = CSV.read(string("logs\\",name,".txt"))

inc_ff = Vector{Float64}()
inc = Vector{Float64}()

lb_ff = Vector{Float64}()
lb = Vector{Float64}()

rank_ff = Vector{Float64}()
rank = Vector{Float64}()

time_ff = Vector{Float64}()
time = Vector{Float64}()

time_inc_ff = Vector{Float64}()
time_inc = Vector{Float64}()

time_ff = Vector{Float64}()
time = Vector{Float64}()

lbs_ff = maximum(data_ff[:lb][:])
lbs = maximum(data[:lb][:])
lbs = maximum([lbs_ff, lbs])

for (i, value) in enumerate(data_ff[:incumbent][:])
        new_inc = 100 * (value - lbs) / lbs
        if new_inc < 2000.0
                push!(inc_ff, new_inc)
                push!(time_inc_ff, data_ff[:time][i])
        end
end

for (i, value) in enumerate(data[:incumbent][:])
        new_inc = 100 * (value - lbs) / lbs
        if new_inc < 2000.0
                push!(inc, new_inc)
                push!(time_inc, data[:time][i])
        end
end

for (i, value) in enumerate(data_ff[:lb][:])
        new_lb = 100 * (value - lbs) / lbs
        push!(lb_ff, new_lb)
end

for (i, value) in enumerate(data[:lb][:])
        new_lb = 100 * (value - lbs) / lbs
        push!(lb, new_lb)
end

for (i, value) in enumerate(data_ff[:time][:])
        push!(time_ff, value)
        push!(rank_ff, data_ff[:rank][:][i])
end

for (i, value) in enumerate(data[:time][:])
        push!(time, value)
        push!(rank, data[:rank][:][i])
end

x_lb_ff = Vector{Float64}()
x_lb = Vector{Float64}()
y_lb_ff = Vector{Float64}()
y_lb = Vector{Float64}()
x_inc_ff = Vector{Float64}()
x_inc = Vector{Float64}()
y_inc_ff = Vector{Float64}()
y_inc = Vector{Float64}()
x_inc_r1_ff = Vector{Float64}()
x_inc_r1 = Vector{Float64}()
y_inc_r1_ff = Vector{Float64}()
y_inc_r1 = Vector{Float64}()

cinc = 0
for i in 1:length(inc_ff)
        if i == 1
                push!(x_inc_ff, time_inc_ff[i])
                push!(y_inc_ff, inc_ff[i])
                global cinc += 1
        end
        if i == length(inc_ff)
                push!(x_inc_ff, time_inc_ff[i])
                push!(y_inc_ff, inc_ff[i])
        end
        if i > 1 && i < length(lb_ff)
                if y_inc_ff[cinc] > inc_ff[i]
                        push!(x_inc_ff, time_inc_ff[i])
                        push!(y_inc_ff, y_inc_ff[cinc])
                        push!(x_inc_ff, time_inc_ff[i])
                        push!(y_inc_ff, inc_ff[i])
                        global cinc += 2
                end
        end
end

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
for i in 1:length(lb_ff)
        if i == 1
                push!(x_lb_ff, time_ff[i])
                push!(y_lb_ff, lb_ff[i])
                global clb += 1
        end
        if i == length(lb_ff)
                push!(x_lb_ff, time_ff[i])
                push!(y_lb_ff, lb_ff[i])
        end
        if i > 1 && i < length(lb_ff)
                if y_lb_ff[clb] < lb_ff[i]
                        push!(x_lb_ff, time_ff[i])
                        push!(y_lb_ff, y_lb_ff[clb])
                        push!(x_lb_ff, time_ff[i])
                        push!(y_lb_ff, lb_ff[i])
                        global clb += 2
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

for (i,value) in enumerate(data_ff[:incumbent][:])
        if rank_ff[i] == 1.0
                push!(x_inc_r1_ff, time_ff[i])
                push!(y_inc_r1_ff, 100 * (value - lbs) / lbs)
        end
end

for (i,value) in enumerate(data[:incumbent][:])
        if rank[i] == 1.0
                push!(x_inc_r1, time[i])
                push!(y_inc_r1, 100 * (value - lbs) / lbs)
        end
end

if maximum(time) < 3600
        x_optimal = [maximum(time)]
        y_optimal = [minimum(inc)]
end

fig = figure(figsize=(6, 4))
rc("font",family="serif",style="italic")
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

#ax = fig.add_axes([0.062,0.096,0.925,0.88])#1354
ax = fig.add_axes([0.09,0.096,0.9,0.88])
#ax = fig.add_axes([0.105,0.096,0.88,0.88])
#ax = fig.add_axes([0.085,0.096,0.9,0.88])
#ax = fig.add_axes([0.062,0.096,0.925,0.88])
ax.tick_params(direction="in",top=true,right=true,width=1.4)

for (i,value) in enumerate(keys(ax.spines))
        ax.spines[value].set_linewidth(1.4)
end

#title(string(name,", heuristics"),weight="bold",family="non-serif",style="normal")

grid(color="lightblue",linewidth=0.4)

xlim(left=1,right=maximum(x_lb_ff)+10)
xscale("log")
xlabel("Time \$[s]\$")

ylim(bottom=-0.4,top=3)
#ylabel("\$100\\left(\\frac{x}{lb*}-1\\right)\$")
ylabel("\$lb^{*}\$ gap \$[\\%]\$")
#set_solid_capstyle("butt")
#set_solid_joinstyle("bevel")
plot(x_lb_ff,y_lb_ff,color="black",linestyle="dotted",lw=1.5,label="Lower bound, OTSP")
plot(x_inc_ff,y_inc_ff,color="black",linestyle="solid",lw=1.5,solid_joinstyle="miter",label="Incumbent solution, OTSP")
plot(x_lb,y_lb,color="green",linestyle="dotted",lw=2,label="Lower bound, root process, P-OTSP")
plot(x_inc,y_inc,color="green",linestyle="solid",lw=2,solid_joinstyle="miter",label="Incumbent solution, root process, P-OTSP")
plot(x_inc_r1,y_inc_r1,markerfacecolor="lightblue",marker="x",ms=6,mew=1,mec="navy",linewidth=0,label="Heuristic solutions, worker process, P-OTSP")
plot(x_optimal, y_optimal,markerfacecolor="red",marker="|",ms=8,mew=4,mec="red",linewidth=0,label="Optimal solution, root process, P-OTSP")


legend(loc = "upper left",fancybox=false,edgecolor="black")

savefig(string("plots\\","test1",".pdf"), format = :pdf)
