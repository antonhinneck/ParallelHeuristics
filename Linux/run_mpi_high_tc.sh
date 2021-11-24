#HYDRA_TOPO_DEBUG=1 mpiexec.hydra -n 2 -bind-to core:4 julia run_mpi_high_tc.jl
#HYDRA_TOPO_DEBUG=1 mpiexec.hydra -n 3 -bind-to user:0+1+2+3,4+5,6+7 julia run_mpi_high_tc.jl
HYDRA_TOPO_DEBUG=1 mpiexec.hydra -n 4 -bind-to core:4 julia run_mpi_high_tc.jl