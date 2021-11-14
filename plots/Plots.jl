p = plot(layer(x=[datasources[i][1:(length(datasources[i]) - 5)] for i in cases], y=results_obj_gap, label = toString(results_obj_gap, 4), Geom.label(position = :below), Geom.bar, Theme(default_color = RGB(0.06,0.06,0.06), bar_spacing = 10mm, point_label_color = "white", point_label_font_size = 12pt, point_label_font = "Palatino")),
         layer(x=[datasources[i][1:(length(datasources[i]) - 5)] for i in cases], y=[1 for i in 1:length(results_obj_gap)], Geom.bar, Theme(default_color = RGB(0.84,0.84,0.84), bar_spacing = 5.6mm)),

         Coord.Cartesian(ymin=0,ymax=1),
         Guide.manual_color_key("Model", ["MIP formulation","LP, all lines active"], [RGB(0.06,0.06,0.06), RGB(0.84,0.84,0.84)]),
         Guide.ylabel("Objective Value, relative to LP"),
         Guide.xlabel("Dataset"),
         Guide.title("Objective values, comparison of LP (2) and MIP (3)"),
         Theme(

                major_label_font = "Palatino",
                key_title_font = "Palatino",
                minor_label_color = "black",
                major_label_color = "black",
                key_label_color = "black",
                key_title_color = "black",
                minor_label_font_size = 9pt,
                major_label_font_size = 12pt,
                key_title_font_size = 12pt)
        )

draw(SVG("ObjectiveGap.svg", 7.2inch, 5.2inch), p)

p = plot(layer(x=[datasources[i][1:(length(datasources[i]) - 5)] for i in cases], y=results_obj_gap, label = toString(results_obj_gap, 4), Geom.label(position = :below), Geom.bar, Theme(default_color = RGB(1.0,1.0,1.0), bar_spacing = 10mm, bar_highlight = bh -> RGB(0.0,0.0,0.0), point_label_color = "black", point_label_font_size = 10pt, point_label_font = "Palatino")),
         layer(x=[datasources[i][1:(length(datasources[i]) - 5)] for i in cases], y=[1 for i in 1:length(results_obj_gap)], Geom.bar, Theme(default_color = "lightblue", bar_spacing = 5.6mm)),

         Coord.Cartesian(ymin=0,ymax=1),
         Guide.manual_color_key("Model", ["MIP formulation","LP, all lines active"], ["white", "lightblue"]),
         Guide.ylabel("Objective Value, relative to LP"),
         Guide.xlabel("Dataset"),
         Guide.title("Objective values, comparison of LP (2) and MIP (3)"),
         Theme(

                major_label_font = "Palatino",
                key_title_font = "Palatino",
                minor_label_color = "black",
                major_label_color = "black",
                key_label_color = "black",
                key_title_color = "black",
                minor_label_font_size = 10pt,
                major_label_font_size = 12pt,
                key_title_font_size = 12pt)
        )

draw(SVG("ObjectiveGapClear.svg", 7.2inch, 5.2inch), p)



p = plot(layer(x=datasources, y=results_ct_lp, label = toString(results_ct_lp,5), Geom.label(position = :below), Geom.bar, Theme(default_color = "silver", bar_spacing = 10mm)),
         layer(x=datasources, y=results_ct_milp, label = toString(results_ct_milp,5), Geom.label(position = :above), Geom.bar, Theme(default_color = "black", bar_spacing = 6mm)),

         Coord.Cartesian(ymin=-0.05,ymax=0.4),
         Guide.manual_color_key("Model", ["OPF-LP", "OPF-MILP"], ["silver", "black"]),
         Guide.ylabel("Computation Time [s]"),
         Guide.xlabel("Dataset"),
         Guide.title("Computation Time, Comparison of OPF-LP against OPF-MILP with Transmission Switching"),
         Theme(
                major_label_font = "Palatino",
                key_title_font = "Palatino",
                minor_label_font_size = 9pt,
                major_label_font_size = 12pt,
                key_title_font_size = 12pt)
        )

draw(SVG("ComputationTime.svg", 7.2inch, 5.2inch), p)

p = plot(layer(x=datasources, y=results_ct_lp, label = toString(results_ct_lp,5), Geom.label(position = :below), Geom.bar, Theme(default_color = "silver", bar_spacing = 10mm)),
        layer(x=datasources, y=results_ct_milp, label = toString(results_ct_milp,5), Geom.label(position = :above), Geom.bar, Theme(default_color = "black", bar_spacing = 6mm)),

         Coord.Cartesian(ymin=-0.05,ymax=0.4),
         Guide.manual_color_key("Model", ["OPF-LP", "OPF-MIP"], ["silver", "black"]),
         Guide.ylabel("Computation Time [s]"),
         Guide.xlabel("Dataset"),
         Guide.title("Computation Time, Comparison of OPF-LP against OPF-MILP with Transmission Switching"),
         Theme(
                major_label_font = "Palatino",
                key_title_font = "Palatino",
                minor_label_font_size = 9pt,
                major_label_font_size = 12pt,
                key_title_font_size = 12pt)
        )

draw(SVG("ComputationTime.svg", 7.2inch, 5.2inch), p)

p = plot(layer(x=[i for i in 1:length(results_sub_objective[1])], y=results_sub_objective[1], label = toString(results_sub_objective[1],6), Geom.label(position = :above), Geom.bar, Theme(default_color = "silver", bar_spacing = 2mm)),

         #Coord.Cartesian(ymin=-0.05,ymax=0.4),
         Coord.Cartesian(xmin=0,xmax=20.5),
         #Guide.manual_color_key("Model", ["OPF-LP", "OPF-MILP"], ["silver", "black"]),
         Guide.ylabel("Objective Value"),
         Guide.xlabel("Permutation"),
         Guide.title("Objective Values for different line permutations"),
         Theme(
                major_label_font = "Palatino",
                key_title_font = "Palatino",
                minor_label_font_size = 8pt,
                major_label_font_size = 12pt,
                key_title_font_size = 12pt)
        )

draw(SVG("SubSolutions.svg", 9.2inch, 5.2inch), p)
