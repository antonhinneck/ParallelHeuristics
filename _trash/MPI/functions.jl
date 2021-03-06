function ones_bool(num::T where T <: Integer)

    return [true for i in 1:num]

end

# Parallel Functions
#-------------------

function master_recv_solutions()
# This function is called by the master thread
# everytime the callback function is called.

    solutions_available = false

    mpi_status, message = MPI.irecv(1, 2, cw)
    mpi_status != false ? solutions_available = true : solutions_available = false

    return solutions_available, message
end

# Logger struct to track Gurobi progress
#---------------------------------------

mutable struct Logger
    counter::I where I <: Integer
    bstobj::Vector{R} where R <: Real
    objbnd::Vector{R} where R <: Real
    time::Vector{R} where R <: Real
    src::Vector{R} where R <: Real
end

function save(logger::Logger, vals::Array{Float64,1})
    if logger.counter != 0
        if !(logger.bstobj[logger.counter] == vals[1] && logger.objbnd[logger.counter] == vals[2])
            push!(logger.bstobj, vals[1])
            push!(logger.objbnd, vals[2])
            push!(logger.time, vals[3])
            push!(logger.src, vals[4])
            logger.counter += 1
        end
    else
        push!(logger.bstobj, vals[1])
        push!(logger.objbnd, vals[2])
        push!(logger.time, vals[3])
        push!(logger.src, vals[4])
        logger.counter += 1
    end
end

function write_log(logger::Logger, name::String)
    open(string(name, ".txt"), "w") do f
        for i in 1:logger.counter
            bo = logger.bstobj[i]
            bb = logger.objbnd[i]
            t = logger.time[i]
            src = logger.src[i]
            write(f, string(bo,", ",bb,", ",t,", ",src,"\n"))
        end
    end
end
