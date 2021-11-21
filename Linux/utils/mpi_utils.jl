## DEFINING FUNCTIONS
##-------------------
@inline function irecv_msg(src::I where I <: Integer, msg_type::I where I <: Integer)

    solutions = nothing

    (hasdata, stat) = MPI.Iprobe(src, msg_type, cw)
    if hasdata
            solutions, mpi_status = MPI.recv(src, msg_type, cw)
    end

    return hasdata, solutions
end

@inline function recv_msg(src::I where I <: Integer, msg_type::I where I <: Integer)

    terminate = false
    message = nothing
    has_data = false

    stat = MPI.Probe(src, msg_type, cw)
    count = MPI.Get_count(stat, Int32)

    if count == NULL
            terminate = true
            println("[INFO] TERMINATE RECEIVED ON RANK ", rank,". SHUTTING DOWN.")
    end

    if !terminate

            if msg_type == MSG_INCUMBENT
                    message, has_data = MPI.recv(src, msg_type, cw)
                    try
                            if typeof(message) == Array{Float64,1}
                                    has_data = true
                            else
                                    has_data = false
                            end
                    catch e
                            has_data = false
                    end
            else
                    message, has_data = MPI.recv(src, msg_type, cw)
            end
    end

    return has_data, message, terminate
end