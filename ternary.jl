#=
This program benchmarks the performance of a ternary conditional expression
in place of using an if-else block. This is done by iterating over 10^7 random
floats that are normally distributed between [0, 1). A retrun value is incrumented
or decrumented at each iteration, using a conditional block or a ternary statement.

This benchmark is performed in C and Julia, where the results are reported to the
console. There appears to be no major performance differences on my machine.

author: Daniel Henderson
=#
using BenchmarkTools
using Libdl

V = rand(10^7)

# ---------------------- Julia declaration
function ternary(V)
    ret = 0
    for v in V
        v < 0.5 ? (ret += 1) : (ret -= 1)
    end
    ret
end

function conditional(V)
    ret = 0
    for v in V
        if v < 0.5
            ret += 1
        else
            ret -= 1
        end
    end
    ret
end


# ---------------------- C declaration
C_code_cond = """
#include <stddef.h>
int c_conditional(size_t n, double *V) {
    int ret = 0;
    for (size_t i = 0; i < n; ++i) {
        if (V[i] < 0.5) {
            ret++;
        } else {
            ret--;
        }
    }
    return ret;
}
"""

C_code_ternary = """
#include <stddef.h>
int c_ternary(size_t n, double *V) {
    int ret = 0;
    for (size_t i = 0; i < n; ++i) {
        (V[i] < 0.5) ? ret++ : ret--;
    }
    return ret;
}
"""

# compile C code to a temp-shared directory w/ gcc and no optimization
const Clib_c = tempname()
open(`gcc -fPIC -msse3 -xc -shared -o $(Clib_c * "." * Libdl.dlext) -`, "w") do f
    print(f, C_code_cond)
end
const Clib_t = tempname()
open(`gcc -fPIC -msse3 -xc -shared -o $(Clib_t * "." * Libdl.dlext) -`, "w") do f
    print(f, C_code_ternary)
end

# create a Julia aliases to call the C functions
c_conditional(V::Array{Float64}) = ccall(("c_conditional", Clib_c), Int64, (Csize_t, Ptr{Float64}), length(V), V)
c_ternary(V::Array{Float64}) = ccall(("c_ternary", Clib_t), Int64, (Csize_t, Ptr{Float64}), length(V), V)


# ---------------------- Benchmark and Report
println("\nIs ternary() similar to conditional()? ", ternary(V) ≈ conditional(V))
t_bench_Julia = @benchmark ternary(V)
c_bench_Julia = @benchmark conditional(V)

println("\nRESULT OF ternary() -------------------------------------------------")
display(t_bench_Julia)

println("\n\nRESULT OF conditional() ---------------------------------------------")
display(c_bench_Julia)

println("\n\n\nIs c_ternary() similar to c_conditional()? ", c_ternary(V) ≈ c_conditional(V))
t_bench_C = @benchmark c_ternary(V)
c_bench_C = @benchmark c_conditional(V)

println("\nRESULT OF c_ternary() -------------------------------------------------")
display(t_bench_C)

println("\n\nRESULT OF c_conditional() ---------------------------------------------")
display(c_bench_C)
println()
