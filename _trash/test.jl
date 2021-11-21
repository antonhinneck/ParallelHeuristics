using Gurobi

simple_model_env = Gurobi.Env()
setparam!(simple_model_env, "OutputFlag", 0)

simple_model = Gurobi.Model(simple_model_env, "simple_mip", :maximize)

add_ivar!(simple_model, 0., 0, Inf)  # p1
add_ivar!(simple_model, 0., 0, Inf)  # p2
add_ivar!(simple_model, 0., 0, Inf)  # p3
add_cvar!(simple_model, 1., 0., Inf) # z
update_model!(simple_model)

add_constr!(simple_model, [3., 5., 4., -1.], '<', 0.)
add_constr!(simple_model, [0.5, 2., 1., 0.], '<', 6.)
add_constr!(simple_model, [3., 5., 4., -1.], '>', 0.)

setparam!(simple_model, "Heuristics", 0.0)
setparam!(simple_model, "Presolve", 0)

update_model!(simple_model)
