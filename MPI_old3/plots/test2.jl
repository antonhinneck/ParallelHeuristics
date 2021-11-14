using JuMP
using Gurobi

set = [i for i in 1:10]
#scenarios = [i for i in 2:10]
sol = zeros(length(set))

m = Model()

#@variable(m, z[s=set] >= 0)
#@variable(m, x[s=set] >= 0)
@variable(m, z[s=set] >= 0, start=sol[s])
@objective(m, Min, sum(z[s] for s in set))

for i in 1:length(set)
    set_start_value(z[i], sol[i])
end

optimize!(m, with_optimizer(Gurobi.Optimizer))
