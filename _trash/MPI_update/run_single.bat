set T=%TIME%
echo %T%
SET JuliaPath="C:\Users\Anton Hinneck\AppData\Local\Programs\Julia\Julia-1.4.1\bin"
SET ProgramDir="C:\Users\Anton Hinneck\Google Drive\Research\TransmissionSwitching\MPI_update\run_single.jl"

cd %JuliaPath%

julia %ProgramDir%

cmd \k
