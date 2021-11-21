ds1951s = [[1870286.36, 1866700.93, 0],
[1869646.7238, 1866700.93, 207],
[1869075.0589, 1866700.93, 312],
[1867307.3009, 1866700.93, 731],
[1866767.9280, 1866700.93, 755]]

x1951s = Vector{Float64}()
y1951s = Vector{Float64}()

for i in 1:length(ds1951s)
        if ds1951s[i][1] != nothing
                push!(y1951s, 100 * (ds1951s[i][1] - ds1951s[i][2]) / ds1951s[i][2])
                push!(x1951s, ds1951s[i][3])
        end
end

ds1951p = [[1870286.3606, 1866700.93, 3],
[1868671.8266, 1866700.93, 66],
[1868634.2708, 1866700.93, 83],
[1868318.5207, 1866700.93, 177],
[1867969.6768, 1866700.93, 178],
[1867642.3105, 1866700.93, 178],
[1867599.6700, 1866700.93, 196],
[1867503.5187, 1866700.93, 196],
[1867259.7032, 1866700.93, 217],
[1866948.2941, 1866700.93, 241],
[1866913.5958, 1866700.93, 258],
[1866767.8303, 1866700.93, 316]]

x1951p = Vector{Float64}()
y1951p = Vector{Float64}()

for i in 1:length(ds1951p)
        if ds1951p[i][1] != nothing
                push!(y1951p, 100 * (ds1951p[i][1] - ds1951p[i][2]) / ds1951p[i][2])
                push!(x1951p, ds1951p[i][3])
        end
end


using PyPlot
using Colors
cd(@__DIR__)

fig = figure(figsize=(6.8, 2.6))
rc("font",family="serif",style="italic", size = 12)
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

ax = fig.add_axes([0.112, 0.18, 0.88, 0.8])

ax.tick_params(direction = "in", top = false, right = false, width = 0.8)

ax.spines["top"].set_visible(false)
ax.spines["right"].set_visible(false)

for (i,value) in enumerate(keys(ax.spines))
        ax.spines[value].set_linewidth(0.6)
end
yscale("log")
ylim(bottom = 0.0025, top = 0.25)

xlabel("Time \$[s]\$")
ylabel("gap \$[\\%]\$")

#plot(x1354, y1354, color = "orange", linestyle = "dotted", lw = 0.8, label = "OTSP, no mipstart", marker = "D", ms = 2.0)
plot(x1951s, y1951s, color = "limegreen", linestyle = "dotted", lw = 1.0, label = "OTSP, mipstart", marker = "D", ms = 3.2)
plot(x1951p, y1951p, color = "darkblue", linestyle = "dotted", lw = 1.0, label = "P-OTSP", marker = "D", ms = 3.2)

plot(x1951s[length(x1951s)], y1951s[length(y1951s)], color = "limegreen", linestyle = "dotted", lw = 0.8, marker = "o", ms = 6.0)
annotate("optimal", (x1951s[length(x1951s)] - 82, y1951s[length(y1951s)] - y1951s[length(y1951s)] * 0.08), size = 10)
plot(x1951p[length(x1951p)], y1951p[length(y1951p)], color = "darkblue", linestyle = "dotted", lw = 0.8, marker = "o", ms = 6.0)
annotate("optimal", (x1951p[length(x1951p)] + 10, y1951p[length(y1951p)] - y1951p[length(y1951p)] * 0.08), size = 10)

leg = legend(loc = "upper right", framealpha = 0.0, fancybox = false, edgecolor = "white")
leg.get_frame().set_linewidth(0.0)
fig.tight_layout()

name = "final1951"

savefig(string("plots\\",name,".pdf"), format = :pdf)
