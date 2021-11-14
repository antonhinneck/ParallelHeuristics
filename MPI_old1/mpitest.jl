using MPI

MPI.Init()

cw = MPI.COMM_WORLD
size = MPI.Comm_size(cw)
rank = MPI.Comm_rank(cw)

if rank == 0

    optimizer = true
    MPI.send(optimizer, 1, 0, cw)

else

    optimizer = false
    print(optimizer)
    optimizer, mpi_status = MPI.recv(0,0, cw)
    print(optimizer)

end

MPI.Finalize()
