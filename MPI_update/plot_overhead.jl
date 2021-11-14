j_start = [0.184, 0.301, 0.321]
mpi_init = [0.0, 0.505, 0.033]
j_pkg = [18.57, 19.29, 19.72]

cases = ["118_ieee", #2
        "588_sdet", #37
        "1354_pegase", #3
        "1951_rte", #9
        "2383_wp_k", #13
        "3375sp_k", #31
        "6470_rte", #40
        "13659_pegase"] #4

cnum = [1, #2
        2, #37
        3, #3
        5, #9
        6, #13
        12, #31
        13, #40
        14] #4

j_model = [[9.875, 10.59], #2
                [9.854, 10.831], #37
                [10.036, 10.54], #3
                [9.826, 10.372], #9
                [9.821, 10.31], #13
                [10.0, 10.588], #31
                [9.909, 10.753], #40
                [10.702, 11.467]] #4

j_data = [[4.47, 4.84], #2
                [5.234, 5.61], #37
                [5.112, 5.376], #3
                [5.59, 5.83], #9
                [5.62, 5.68], #13
                [6.31, 6.567], #31
                [7.716, 7.937], #40
                [11.459, 11.605]] #4

g_pre = [[0.213, 0.72], #2
                [0.323, 1.263], #37
                [0.81, 1.2], #3
                [0.82, 1.405], #9
                [2.715, 3.32], #13
                [4.04, 4.578], #31
                [6.63, 6.41], #40
                [25.844, 26.057]] #4

profiling = [0.050426100523777884, #Snd rqsts / s
        0.005160269639137833, #Snd rqst time / s
        71.35293224114571, #Recv rqsts / s
        0.0014455516454404548, #Recv rqst time / s
        4245, #Recv rqsts
        0.08600020408630371, #Recv time
        59.4930000305] # time

using PyPlot
using Colors
cd(@__DIR__)

fig = figure(figsize=(6.8, 2.2))
rc("font",family="serif",style="italic", size = 12)
rc("mathtext",fontset="dejavuserif")
rc("lines",linewidth=1)

ax = fig.add_axes([0.084, 0.21, 0.91, 0.78])
#
# ax.tick_params(direction = "in", top = false, right = false, width = 0.8)
#
ax.spines["top"].set_visible(false)
ax.spines["right"].set_visible(false)
#
# for (i,value) in enumerate(keys(ax.spines))
#         ax.spines[value].set_linewidth(0.6)
# end
#yscale("log")
ylim(bottom = -5, top = 34)
xlim(left = 0, right = 8.8)

xlabel("Case")
ylabel("Time \$[s]\$")

x = [i for i in 1:length(cases)]
xticks(x, labels = [string(c) for c in cnum])

#plot(x1354, y1354, color = "orange", linestyle = "dotted", lw = 0.8, label = "OTSP, no mipstart", marker = "D", ms = 2.0)
plot(x, [g[1] for g in g_pre], color = "limegreen", linestyle = "dotted", lw = 1.0, label = "Preprocessing, OTSP", marker = "D", ms = 3.2)
plot(x, [g[2] for g in g_pre], color = "darkblue", linestyle = "dotted", lw = 1.0, label = "Preprocessing, P-OTSP", marker = "D", ms = 3.2)

for (i, g) in enumerate(g_pre)
        annotate(string(g[1]), (i - 0.0, g[1] - 4), size = 10)
        annotate(string(g[2]), (i - 0.0, g[2] + 2), size = 10)
end

# plot(x1951s[length(x1951s)], y1951s[length(y1951s)], color = "limegreen", linestyle = "dotted", lw = 0.8, marker = "o", ms = 6.0)
# annotate("optimal", (x1951s[length(x1951s)] - 82, y1951s[length(y1951s)] - y1951s[length(y1951s)] * 0.08), size = 10)
# plot(x1951p[length(x1951p)], y1951p[length(y1951p)], color = "darkblue", linestyle = "dotted", lw = 0.8, marker = "o", ms = 6.0)
# annotate("optimal", (x1951p[length(x1951p)] + 10, y1951p[length(y1951p)] - y1951p[length(y1951p)] * 0.08), size = 10)

leg = legend(loc = "upper left", framealpha = 0.0, fancybox = false, edgecolor = "white")
leg.get_frame().set_linewidth(0.0)
fig.tight_layout()

name = "grb_pre"
savefig(string("plots\\",name,".pdf"), format = :pdf)
