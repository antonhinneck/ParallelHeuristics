using JuMP, Gurobi, Gadfly, DataStructures, Colors
using MathOptInterface ## Cbc, GLPK, HTTP, JSON
include("C:/Users/Anton Hinneck/.julia/packages/PowerGrids/src/PowerGrids.jl")

cd(@__DIR__)

include("Functions.jl")
include("Model_LP.jl")
include("Model_MIP.jl")

const THETAMAX = 0.5235
const THETAMIN = -0.5235
const grb_env = Gurobi.Env()

cases = [5, 26, 28, 37]

datasources = PowerGrids.datasets(true)

#=
datasources =   [
                    "pglib_opf_case3_lmbd.xlsx",
                    "pglib_opf_case5_pjm.xlsx",
                    "pglib_opf_case14_ieee.xlsx",
                    "pglib_opf_case24_ieee_rts.xlsx",
                    "pglib_opf_case30_as.xlsx",
                    "pglib_opf_case30_fsr.xlsx",
                    "pglib_opf_case30_ieee.xlsx",
                    "pglib_opf_case39_epri.xlsx",
                    "pglib_opf_case57_ieee.xlsx",
                    "pglib_opf_case73_ieee_rts.xlsx",
                    "pglib_opf_case89_pegase.xlsx",
                    "pglib_opf_case118_ieee.xlsx",
                    "pglib_opf_case162_ieee_dtc.xlsx"
                ]
=#

results_ct_lp = Vector{Float64}()
results_ct_milp = Vector{Float64}()
results_obj_lp = Vector{Float64}()
results_obj_milp = Vector{Float64}()
results_obj_gap = Vector{Float64}()

results_sign = Vector{Vector{Float64}}()
results_pf = Vector{Vector{Float64}}()
results_duals = Vector{Vector{Float64}}()
results_duals_sorted = Vector{SortedDict{Number, Number}}()
results_switched = Vector{Vector{Float64}}()
results_switched_rl = Vector{Vector{Float64}}()

results_sub_objective = Vector{Float64}()

for i in 1:length(cases)

    print("\n\n-------------------------------------------\n")
    print("Solving LP and MILP, Dataset: ", datasources[cases[i]],"\n")
    print("-------------------------------------------\n")
    data = PowerGrids.readDataset(datasources[cases[i]])

    line_vector = [true for i in 1:length(data.lines)]
    time_lp, status_lp, objective_lp, solution_lp, duals_lp = solve_TS_LP(grb_env, data, line_vector)

    time_mip, objective_mip, solution_mip = solve_TS_MIP(data)

    push!(results_ct_lp, time_lp)
    push!(results_ct_milp, time_mip)
    push!(results_obj_lp, objective_lp)
    push!(results_obj_milp, objective_lp)
    push!(results_obj_gap, objective_mip / objective_lp)

end

cd(@__DIR__)

#include("Plots.jl")


#postBody = JSON.json(data.jsonModel)
#HTTP.request("POST", "http://localhost:8080/data/upload", ["Content-Type" => "application/json;charset=UTF-8"], postBody)

#JSON.print(stdout, data.jsonModel, 2)

#include("Model_switching.jl")

print("---------------------------------------------------------")

#print([keys(results_duals_sorted[1])...])

names = datasources[cases]
for i in 1:length(names)
    names[i] = names[i][11:(length(names[i])-5)]
end

p = plot(layer(y=names, x=results_obj_gap, Geom.label(position = :right), Geom.bar(orientation = :horizontal), label = toString(results_obj_gap, 4), Theme(default_color = "black", bar_spacing = 4.6mm, point_label_color = "black", point_label_font_size = 9pt, point_label_font = "Palatino")),
         #layer(y=names, x=[1 for i in 1:length(cases)], Geom.bar(orientation = :horizontal), Theme(bar_highlight = bh -> "navy", default_color = "navy", bar_spacing = 2.8mm)),

         Coord.Cartesian(xmin=0,xmax=1.2, ymin = 0.5, ymax = length(cases) + 0.5),
         Guide.manual_color_key("Model", ["MIP formulation","LP, all lines active"], [RGB(1,1,1), "navy"]),
         Guide.ylabel("Case"),
         Guide.xticks(ticks = nothing),
         Guide.xlabel("OTSP objective / DCOPF objective"),
         #Guide.title("Comparison of OTSP and DCOPF objective values"),
         Theme(
                major_label_font = "Times",
                minor_label_font = "Times",
                key_title_font = "Times",
                minor_label_color = "black",
                major_label_color = "black",
                key_label_color = "black",
                key_title_color = "black",
                grid_line_width = 0mm,
                minor_label_font_size = 10pt,
                major_label_font_size = 11pt,
                key_title_font_size = 11pt,
                key_position = :none)
        )

draw(SVG("Switched2.svg", 5inch, 2inch), p)
#=
p = plot(#layer(x=[i for i in 1:length(results_switched[1])], y=results_switched[1], label = toString(results_switched, 2), Geom.label(position = :above), Geom.bar, Theme(default_color = "silver", bar_spacing = 10mm)),
         layer(x=[i for i in 1:length(results_switched_rl[1])], y=results_switched_rl[1], Geom.bar, Theme(default_color = "black", bar_spacing = 0.3mm)),
         layer(x=[i for i in 1:length(results_switched[1])], y=results_switched[1], Geom.bar, Theme(default_color = "blue", bar_spacing = 0.2mm)),
         layer(x=[i for i in 1:length(results_duals[1])], y=results_duals[1] / 10, Geom.bar, Theme(default_color = "gray", bar_spacing = 0.1mm)),

         Coord.Cartesian(xmin = 0, xmax = length(results_switched[1]), ymin = minimum(results_duals[1] / 10), ymax = maximum(results_duals[1]) / 10),
         Guide.manual_color_key("Variables", ["Operational status", "Dual value", "Operational Status, Relaxed"], ["blue", "gray", "black"]),
         Guide.ylabel("Line Status"),
         Guide.xlabel("Line"),
         Guide.title("Results, Operational Status of Lines"),
         Theme(
                major_label_font = "Palatino",
                key_title_font = "Palatino",
                minor_label_font_size = 9pt,
                major_label_font_size = 12pt,
                key_title_font_size = 12pt)
        )

draw(SVG("DualsSwitched2.svg", 12.2inch, 5.2inch), p)=#
