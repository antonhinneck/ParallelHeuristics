SET JuliaPath="C:\Users\Anton Hinneck\AppData\Local\Julia-1.2.0-rc2\bin"
SET ProgramDir="C:\Users\Anton Hinneck\Google Drive\Research\TransmissionSwitching\MPI\Run_MPI.jl"
SET LogFile="C:\Users\Anton Hinneck\Desktop\log.txt"

cd %JuliaPath%

mpiexec -hosts 2 localhost 1,8 localhost 1,7 julia %ProgramDir%

cmd \k
