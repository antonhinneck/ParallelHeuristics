p = plot(layer(x=datasources, y=results_obj_gap, label = toString(results_obj_gap, 4), Geom.label(position = :below), Geom.bar, Theme(default_color = "silver", bar_spacing = 10mm)),
        layer(x=datasources, y=[1 for i in 1:length(results_obj_gap)], Geom.bar, Theme(default_color = "black", bar_spacing = 6mm)),

         Coord.Cartesian(ymin=0,ymax=1),
         Guide.manual_color_key("Model", ["OPF-LP", "OPF-MILP"], ["black", "silver"]),
         Guide.ylabel("Objective Value, relative to LP"),
         Guide.xlabel("Dataset"),
         Guide.title("Objective Value, Comparison of OPF-LP against OPF-MILP with Transmission Switching"),
         Theme(
                major_label_font = "Palatino",
                key_title_font = "Palatino",
                minor_label_font_size = 9pt,
                major_label_font_size = 12pt,
                key_title_font_size = 12pt)
        )

draw(SVG("ObjectiveGap.svg", 7.2inch, 5.2inch), p)

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
