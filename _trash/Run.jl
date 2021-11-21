using JuMP, Gurobi, Gadfly, DataStructures
using MathOptInterface ## Cbc, GLPK, HTTP, JSON
include("C:/Users/Anton Hinneck/.julia/packages/PowerGrids/src/PowerGrids.jl")

#TEST
#a = generate_line_vectors([1,2,3])

cd(@__DIR__)
#include("DataInput.jl")
include("Functions.jl")
include("Model_flow.jl")
include("Model_flow_cb.jl")
include("Model_flow_search.jl")
include("Model_flow_dualSearch.jl")
include("Model_switching.jl")
include("Model_switchingRelax.jl")

datasources = PowerGrids.datasets()

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

heuristic = true

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

for i in 1:1

    print("\n\n-------------------------------------------\n")
    print("Solving LP and MILP, Dataset: ", datasources[i],"\n")
    print("-------------------------------------------\n")
    data = PowerGrids.readDataset(datasources[i])
    #ct_lp, obj_lp, pf = solve_TS_LP(data)
    #push!(results_pf, pf)

    #push!(results_sign, sign_array(pf))

    #line_capacity = Dict{Int64, Float64}()
    #for j in 1:length(pf)
        #push!(line_capacity, data.lines[j] => pf[j])
    #end
    #a, b, duals = solve_TS_DualLP(data, line_capacity)
    #push!(results_duals, duals)

    #push!(results_duals_sorted, SortedDict(zip(duals, data.lines))) #sign_array(pf) .*

    #ct_milp, switched = solve_TS_MILP(data)
    #ct_milp, switched_rl = solve_TS_MILP_RL(data)
    #push!(results_switched, switched)
    #push!(results_switched_rl, switched_rl)
    print("-------------------------------------------")

    #push!(results_ct_lp, ct_lp)
    #push!(results_ct_milp, ct_milp)
    #push!(results_obj_lp, obj_lp)
    #push!(results_obj_milp, obj_milp)
    #push!(results_obj_gap, obj_milp / obj_lp)

    if heuristic
        #line_vectors = generate_line_vectors(data.lines, subset = [values(results_duals_sorted[1])...])
        ts = MathOptInterface.TerminationStatusCode(2)
        c = 0
        while c < 100 && ts != MathOptInterface.TerminationStatusCode(1)
            line_vectors = PowerGrids.line_vector(PowerGrids.adjacency_list(PowerGrids.paton(PowerGrids.toGraph(data).Graph, initialization = :rnd)[2]), data)
            #print("Line Vectors: \n")
            #print("--------------\n")
            #print(line_vectors)
            #push!(results_sub_objective, Vector{Any}())
            ts = solve_TS_LP_Search(data, line_vectors)
            c += 1
        end
        #for j in 1:length(line_vectors)
            #sub_obj_lp = 0

            #catch
                #sub_obj_lp = 0
            #end
            #push!(results_sub_objective[i], sub_obj_lp)
        #end
        #print("results_sub_objective")
    end
end

print("LP Solution:\n")
print("------------\n")
#print(results_obj_lp)
print("\nMILP Solution:\n")
print("------------\n")
#print(results_obj_milp)
print("\nHeuristic Solutions:\n")
print("------------\n")
#print(results_sub_objective[1])

cd(@__DIR__)
#include("Plots.jl")


#postBody = JSON.json(data.jsonModel)
#HTTP.request("POST", "http://localhost:8080/data/upload", ["Content-Type" => "application/json;charset=UTF-8"], postBody)

#JSON.print(stdout, data.jsonModel, 2)

#include("Model_switching.jl")

print("---------------------------------------------------------")

#print([keys(results_duals_sorted[1])...])
#=
p = plot(#layer(x=[i for i in 1:length(results_switched[1])], y=results_switched[1], label = toString(results_switched, 2), Geom.label(position = :above), Geom.bar, Theme(default_color = "silver", bar_spacing = 10mm)),
         layer(x=[i for i in 1:length(results_switched[1])], y=results_switched[1], Geom.bar, Theme(default_color = "black", bar_spacing = 0.2mm)),

         Coord.Cartesian(ymin=0,ymax=1, xmin = 0, xmax = length(results_switched[1])),
         Guide.manual_color_key("Model", ["OPF-LP", "OPF-MILP"], ["black", "silver"]),
         Guide.ylabel("Line Status"),
         Guide.xlabel("Line"),
         Guide.title("Results, Operational Status of Lines"),
         Theme(
                major_label_font = "Palatino",
                key_title_font = "Palatino",
                minor_label_font_size = 9pt,
                major_label_font_size = 12pt,
                key_title_font_size = 12pt,
                key_position = :none)
        )

draw(SVG("Switched2.svg", 12.2inch, 3.2inch), p)

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
