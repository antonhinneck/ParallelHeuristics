function solve_TS_LP_Search(data, lines)

    TS = Model()

    @variable(TS, generation[data.generators] >= 0)
    @variable(TS, theta[data.buses] >= 0)
    @variable(TS, power_flow_var[lines])
    #@variable(TS, switched[data.lines], Bin)

    #heuristic = true

    #JuMP.fix(switched[1], 1; force = true)

    #Set angle at slack node
    #JuMP.fix(theta[1], 0; force = true)

    #Minimal generation costs
    @objective(TS, Min, sum(data.generator_costs[g] * generation[g] for g in data.generators))

    #Current law
    @constraint(TS, market_clearing[n = data.buses],
    sum(generation[g] for g in data.generators_at_bus[n]) + sum(power_flow_var[l] for l in data.lines_start_at_bus[n] if l in Set(lines)) - sum(power_flow_var[l] for l in data.lines_end_at_bus[n] if l in Set(lines)) == data.bus_demand[n])

    #Voltage law
    @constraint(TS, voltage_1[l = lines],
    (data.base_mva / data.line_reactance[l]) * (theta[data.line_start[l]] - theta[data.line_end[l]]) == power_flow_var[l])

    #Capacity constraint
    @constraint(TS, production_capacity[g = data.generators], generation[g] <= data.generator_capacity[g])

    #Angle limits
    @constraint(TS, theta_limit_1[n = data.buses], theta[n] <=  pi)

    #Line limit
    @constraint(TS, power_flow_limit_1[l in lines], power_flow_var[l] <= data.line_capacity[l])
    @constraint(TS, power_flow_limit_2[l in lines], power_flow_var[l] >= -data.line_capacity[l])

    t = time()
    optimize!(TS, with_optimizer(Gurobi.Optimizer))

    #status = optimize!(TS, with_optimizer(GLPK.Optimizer, msg_lev = 3))
    #status = optimize!(TS, with_optimizer(Cbc.Optimizer, LogLevel = 1))
    te = time()

    #Returing Results
    #----------------
    #print("Time:\n")
    #print(te-t,"\n")
    #print("Costs:\n")
    #print(JuMP.objective_value(TS))
    #print("\nGeneration:\n")
    #print(value.(generation).data)
    #print("\n",adjacency)
    #print("\n",getvalue(theta))
    #print("\nPowerFlow:\n")
    #print("\n",value.(power_flow_var).data)
    #print("\nTheta:\n")
    #print(value.(theta).data)

    #print("LP - Time: ", te-t,", Objective Value: ",JuMP.objective_value(TS),".\n")

    #return te-t, JuMP.objective_value(TS)
    return termination_status(TS)
end
