using JuMP

TS = Model()

set = [i for i in 1:10]
idctr = Array{Bool, 1}(undef, length(set))
for i in 1:length(set)
    rnd = rand()
    if rnd > 0.5
        idctr[i] = true
    else
        false
    end
end

@inline function idctr_function()
    return true
end

@variable(TS, v[set] >= 0; idctr_function(set) == true)

using Base.Meta

function _extract_kw_args(args)
    kw_args = filter(x -> isexpr(x, :(=)) && x.args[1] != :container , collect(args))
    print(kw_args)
    flat_args = filter(x->!isexpr(x, :(=)), collect(args))
    requestedcontainer = :Auto
    for kw in args
        if isexpr(kw, :(=)) && kw.args[1] == :container
            requestedcontainer = kw.args[2]
        end
    end
    return flat_args, kw_args, requestedcontainer
end

macro testm(args...)

    arg1, arg2 = _extract_kw_args(args)

end

@testm(test[1:2])

filter(test[1:2])

x = :(2=2)
isexpr(x, :(=))
