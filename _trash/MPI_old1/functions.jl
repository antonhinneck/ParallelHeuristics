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
