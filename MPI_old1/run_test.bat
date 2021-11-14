SET JuliaPath="C:\Users\Anton Hinneck\AppData\Local\Julia-1.2.0-rc2\bin"
SET ProgramDir="C:\Users\Anton Hinneck\Google Drive\Research\TransmissionSwitching\MPI\mpitest.jl"
SET LogFile="C:\Users\Anton Hinneck\Desktop\log.txt"

cd %JuliaPath%

mpiexec -n 2 %JuliaPath%\julia %ProgramDir%

cmd \k
