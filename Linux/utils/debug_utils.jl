## This function prints JuMP constraints, based on optimizer id.
## Only works with Gurobi.
function GRBUjumpconstrbyoptindex(m::JuMP.Model, constrnum::T where T <: Integer)

    gm = backend(m).optimizer.model
    @assert typeof(gm) == Gurobi.Optimizer

    nnz = Ref{Cint}()
    GRBgetconstrs(gm,nnz,C_NULL,C_NULL,C_NULL,constrnum, 1)
    nnz[]

    cbeg = Array{Cint, 1}(undef, nnz[])
    cind = Array{Cint, 1}(undef, nnz[])
    cval = Array{Cdouble, 1}(undef, nnz[])

    GRBgetconstrs(gm,nnz,cbeg,cind,cval,constrnum,1)

    # println(nnz[])
    # println(cbeg)
    # println(cind)
    # println(cval)

    for i in 1:nnz[]
        _varname = name(VariableRef(m, m.moi_backend.optimizer_to_model_map[VariableIndex(i)]))
        print( string(cval[i]," * ",_varname) )
        if i != nnz[]
            print(" + ")
        end
    end

    val = Ref{Cdouble}()
    GRBgetdblattrelement(gm,"RHS",constrnum,val)

    print(" <= ")
    println(string(val[]))

end

## Returns constraint ids of iis constraints
function GRButils_getIISconstrs(m::JuMP.Model)
    grbm = backend(m).optimizer.model
    nc = Ref{Cint}()
    GRBgetintattr(grb_model, "NumConstrs", nc)
    _constrs = Vector{Int64}()
    for i in 0:(nc[] - 1)
        _is = Ref{Cint}()
        GRBgetintattrelement(grb_model, "IISConstr", i, _is)
        if _is[] == Cint(1)
            push!(_constrs, i)
        end
    end
    return _constrs
end

# iis = GRBcomputeIIS(backend(m).optimizer.model)
# cons = GRButils_getIISconstrs(m)
# for i in cons
#     GRBUjumpconstrbyoptindex(m, i)
# end