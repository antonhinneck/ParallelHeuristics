ds3120s = [[1397790.56, 1343836.21, 3],
[1394064.6886, 1343836.21, 162],
[1373989.6872, 1343836.21, 162],
[1373989.69, 1343836.21, 900]]

x3120s = Vector{Float64}()
y3120s = Vector{Float64}()

for i in 1:length(ds3120s)
        if ds3120s[i][1] != nothing
                push!(y3120s, 100 * (ds3120s[i][1] - ds3120s[i][2]) / ds3120s[i][2])
                push!(x3120s, ds3120s[i][3])
        end
end

ds3120p = [[1397790.5607, 1343836.21, 6],
[1386730.2237, 1343836.21, 26],
[1384254.3733, 1343836.21, 26],
[1378571.5278, 1343836.21, 26],
[1376370.4917, 1343836.21, 27],
[1373059.8498, 1343836.21, 44],
[1369110.4951, 1343836.21, 60],
[1366089.1610, 1343836.21, 104],
[1364935.9666, 1343836.21, 104],
[1364877.2733, 1343836.21, 117],
[1361556.8087, 1343836.21, 128],
[1361556.5020, 1343836.21, 128],
[1360146.1733, 1343836.21, 276],
[1359916.1062, 1343837.67, 332],
[1359914.9290, 1343837.70, 341],
[1358981.6802, 1343837.72, 354],
[1358723.6840, 1343837.72, 354],
[1358713.9173, 1343837.72, 354],
[1358087.5871, 1343837.83, 387],
[1358077.1751, 1343837.83, 389],
[1357929.6645, 1343837.83, 393],
[1357845.5335, 1343837.83, 398],
[1357844.5036, 1343837.83, 398],
[1357844.2755, 1343837.83, 404],
[1357763.7466, 1343837.83, 468],
[1357134.9825, 1343837.83, 520],
[1357005.2349, 1343837.83, 836],
[1357004.4608, 1343837.83, 836],
[1357003.9564, 1343837.83, 836],
[1357003.9564, 1343837.83, 900]]

x3120p = Vector{Float64}()
y3120p = Vector{Float64}()

for i in 1:length(ds3120p)
        if ds3120p[i][1] != nothing
                push!(y3120p, 100 * (ds3120p[i][1] - ds3120p[i][2]) / ds3120p[i][2])
                push!(x3120p, ds3120p[i][3])
        end
end


using PyPlot
using Colors
cd(@__DIR__)

fig = figure(figsize=(6.8, 2.6))
rc("font",family="serif",style="italic", size = 12)
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
plot(x3120s, y3120s, color = "limegreen", linestyle = "dotted", lw = 1.0, label = "OTSP, mipstart", marker = "D", ms = 3.2)
plot(x3120p, y3120p, color = "darkblue", linestyle = "dotted", lw = 1.0, label = "P-OTSP", marker = "D", ms = 3.2)

leg = legend(loc = "upper right", framealpha = 0.0, fancybox = false, edgecolor = "black")
leg.get_frame().set_linewidth(0.0)
fig.tight_layout()

name = "final3120"

savefig(string("plots\\",name,".pdf"), format = :pdf)
