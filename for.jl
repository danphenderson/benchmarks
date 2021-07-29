#=
This script benchmarks the call to a length function as a condition bound
of a for loop verse declaring the iteration length prior to the for loop.

More effiecient to use the length function? Atleast that is what my machine is
suggesting. 
=#
using BenchmarkTools

function forl(X)
    s = 0
    for i in 1:length(X)
        ((i % 2) > 0) ? (s+=1) : (s-=1)
    end
end

function ford(X)
    s = 0
    N = length(X)
    for i in 1:N
        ((i % 2) > 0) ? (s+=1) : (s-=1)
    end
end

x = rand(10^9)

bench_d = @benchmark $ford($x)
bench_l = @benchmark $forl($x)

println("\nDeclared ----------------------")
display(bench_d)

println("\n\nlength() Call ----------------------")
display(bench_l)

println()
