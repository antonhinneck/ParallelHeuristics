function solve_TS_LP_ADD(data, line_vector::Array{Bool, 1}; violation_costs = 10)

    @inline function get_lines_subset()
        lines_subset = Vector{Int16}()
        @assert length(line_vector) == length(data.lines)
        for i in 1:length(line_vector)
            if line_vector[i]
                push!(lines_subset, data.lines[i])
            end
        end
        return lines_subset
    end

    lines_subset = get_lines_subset()

    TS = Model()

    @variable(TS, generation[data.generators] >= 0)
    @variable(TS, theta[data.buses] >= 0)
    @variable(TS, power_flow_var[lines_subset])
    @variable(TS, add_cap[lines_subset] >= 0)
    #@variable(TS, switched[data.lines], Bin)

    #JuMP.fix(switched[1], 1; force = true)
    #JuMP.fix(switched[2], 1; force = true)
    #JuMP.fix(switched[3], 1; force = true)

    #Set angle at slack node
    #JuMP.fix(theta[data.buses[1]], pi; force = true)

    #Minimal generation costs
    @objective(TS, Min, sum(data.generator_costs[g] * generation[g] for g in data.generators) + sum(add_cap[l] * violation_costs for l in lines_subset))

    #Current law
    @constraint(TS, market_clearing[n = data.buses],
    sum(generation[g] for g in data.generators_at_bus[n]) + sum(power_flow_var[l] for l in data.lines_start_at_bus[n] if l in lines_subset) - sum(power_flow_var[l] for l in data.lines_end_at_bus[n] if l in lines_subset) == data.bus_demand[n])

    #Voltage law
    @constraint(TS, voltage_1[l = lines_subset],
    (data.base_mva / data.line_reactance[l]) * (theta[data.line_start[l]] - theta[data.line_end[l]]) == power_flow_var[l])

    #Capacity constraint
    @constraint(TS, production_capacity[g = data.generators], generation[g] <= data.generator_capacity[g])

    #Angle limits
    @constraint(TS, theta_limit_1[n = data.buses], theta[n] <= pi)

    #Line limit
    @constraint(TS, power_flow_limit_1[l in lines_subset], power_flow_var[l] <= data.line_capacity[l] + add_cap[l])
    @constraint(TS, power_flow_limit_2[l in lines_subset], power_flow_var[l] >= -data.line_capacity[l] - add_cap[l])

    t = time()
    optimize!(TS, with_optimizer(Gurobi.Optimizer))
    status = termination_status(TS)
    print(status)

    if status == MOI.TerminationStatusCode(2)
        output = false, [0]
        #get_iis(TS)
    else

        #status = optimize!(TS, with_optimizer(GLPK.Optimizer, msg_lev = 3))
        #status = optimize!(TS, with_optimizer(Cbc.Optimizer, LogLevel = 1))
        te = time()

        pf = value.(power_flow_var).data
        additional_capacity = value.(add_cap).data

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
        print("LP - Time: ", te-t,", Objective Value: ",JuMP.objective_value(TS),".\n")
        output = true, additional_capacity, objective_value(TS)
    end

    return output
end
