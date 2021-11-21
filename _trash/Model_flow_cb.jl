function solve_TS_LP_CB(data)

    TS = Model()

    @variable(TS, generation[data.generators] >= 0)
    @variable(TS, theta[data.buses] >= 0)
    @variable(TS, power_flow_var[data.lines])
    #@variable(TS, switched[data.lines], Bin)

    #JuMP.fix(switched[1], 1; force = true)
    #JuMP.fix(switched[2], 1; force = true)
    #JuMP.fix(switched[3], 1; force = true)

    #Set angle at slack node
    #JuMP.fix(theta[data.buses[1]], pi; force = true)

    #Minimal generation costs
    @objective(TS, Min, sum(data.generator_costs[g] * generation[g] for g in data.generators))

    #Current law
    @constraint(TS, market_clearing[n = data.buses],
    sum(generation[g] for g in data.generators_at_bus[n]) + sum(power_flow_var[l] for l in data.lines_start_at_bus[n]) - sum(power_flow_var[l] for l in data.lines_end_at_bus[n]) == data.bus_demand[n])

    #Voltage law
    @constraint(TS, voltage_1[l = data.lines],
    (data.base_mva / data.line_reactance[l]) * (theta[data.line_start[l]] - theta[data.line_end[l]]) == power_flow_var[l])

    #Capacity constraint
    @constraint(TS, production_capacity[g = data.generators], generation[g] <= data.generator_capacity[g])

    #Angle limits
    @constraint(TS, theta_limit_1[n = data.buses], theta[n] <= pi)

    #Line limit
    @constraint(TS, power_flow_limit_1[l in data.lines], power_flow_var[l] <= data.line_capacity[l])
    @constraint(TS, power_flow_limit_2[l in data.lines], power_flow_var[l] >= -data.line_capacity[l])

    t = time()
    optimize!(TS, with_optimizer(Gurobi.Optimizer, OutputFlag = 0))
    status = termination_status(TS)

    if status == MOI.TerminationStatusCode(2)
        output = [0,0]
        #get_iis(TS)
    else

    #status = optimize!(TS, with_optimizer(GLPK.Optimizer, msg_lev = 3))
    #status = optimize!(TS, with_optimizer(Cbc.Optimizer, LogLevel = 1))
    te = time()

    grb_model = backend(TS).optimizer.model.inner
    output = Gurobi.get_dblattrarray(grb_model, "X", 1, num_vars(grb_model))

    #Returing Results
    #----------------
    #print("Time:\n")
    #print(te-t,"\n")
    #print("Costs:\n")
    #print(JuMP.objective_value(TS),"\n")
    #print("\nGeneration:\n")
    #print(value.(generation).data)
    #print("\n",adjacency)
    #print("\n",getvalue(theta))
    #print("\nPowerFlow:\n")
    #print("\n",value.(power_flow_var).data)


    #print("\nTheta:\n")
    #print(value.(theta).data)
        #print("LP - Time: ", te-t,", Objective Value: ",JuMP.objective_value(TS),".\n")
        #output = [te-t, JuMP.objective_value(TS), pf]
    end

    return status, output
end
