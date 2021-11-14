ds6470s = [[1737256.54, 1576612.06, 6],
[1737256.54, 1577333.77, 10],
[1737256.54, 1577405.81, 15],
[1737256.54, 1577596.01, 17],
[1737256.54, 1577596.01, 900]]

x6470s = Vector{Float64}()
y6470s = Vector{Float64}()

for i in 1:length(ds6470s)
        if ds6470s[i][1] != nothing
                push!(y6470s, 100 * (ds6470s[i][1] - ds6470s[i][2]) / ds6470s[i][2])
                push!(x6470s, ds6470s[i][3])
        end
end

ds6470p = [[1737256.5379, 1576738.39, 11],
[1737256.54, 1577532.79, 14],
[1720866.6527, 1577596.01, 48],
[1689539.7911, 1577596.01, 57],
[1689539.79, 1577798.17, 136],
[1689521.2338, 1577838.16, 178],
[1689511.1421, 1577838.16, 178],
[1688931.2235, 1577838.16, 178],
[1688192.1030, 1577838.16, 178],
[1688181.2535, 1577838.16, 178],
[1687938.9500, 1577838.16, 183],
[1687928.0849, 1577838.16, 183],
[1687525.5766, 1577838.16, 329],
[1686366.4523, 1577838.16, 408],
[1685249.9166, 1577838.16, 408],
[1685249.9166, 1577838.16, 900]]

x6470p = Vector{Float64}()
y6470p = Vector{Float64}()

for i in 1:length(ds6470p)
        if ds6470p[i][1] != nothing
                push!(y6470p, 100 * (ds6470p[i][1] - ds6470p[i][2]) / ds6470p[i][2])
                push!(x6470p, ds6470p[i][3])
        end
end


using PyPlot
using Colors
cd(@__DIR__)

fig = figure(figsize=(6.8, 2.6))
rc("font",family="serif",style="italic",size=12)
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

ax = fig.add_axes([0.14, 0.16, 0.84, 0.82])

ax.tick_params(direction = "in", top = false, right = false, width = 0.8)

ax.spines["top"].set_visible(false)
ax.spines["right"].set_visible(false)

for (i,value) in enumerate(keys(ax.spines))
        ax.spines[value].set_linewidth(0.6)
end
yscale("log")

xlabel("Time \$[s]\$")
ylabel("gap \$[\\%]\$")

#plot(x1354, y1354, color = "orange", linestyle = "dotted", lw = 0.8, label = "OTSP, no mipstart", marker = "D", ms = 2.0)
plot(x6470s, y6470s, color = "limegreen", linestyle = "dotted", lw = 1.0, label = "OTSP, mipstart", marker = "D", ms = 3.2)
plot(x6470p, y6470p, color = "darkblue", linestyle = "dotted", lw = 1.0, label = "P-OTSP", marker = "D", ms = 3.2)

leg = legend(loc = "center right", framealpha = 0.0, fancybox = false, edgecolor = "black")
leg.get_frame().set_linewidth(0.0)
fig.tight_layout()

name = "final6470"

savefig(string("plots\\",name,".pdf"), format = :pdf)
