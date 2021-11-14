set T=%TIME%
echo %T%
SET JuliaPath="C:\Users\Anton Hinneck\AppData\Local\Programs\Julia\Julia-1.4.1\bin"
SET ProgramDir="C:\Users\Anton Hinneck\Google Drive\Research\TransmissionSwitching\MPI_update\Run_MPI.jl"
SET LogFile="C:\Users\Anton Hinneck\Desktop\log.txt"

cd %JuliaPath%

mpiexec -hosts 2 localhost 1,F000 localhost 1,FFF julia %ProgramDir%

cmd \k
