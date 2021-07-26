#=
This script benchmarks the operation of summing over an array of 10^7 elements.
There is lickley a trick here to making python look so bad, our array is natively stored
in column-major form, while python's lists are in row-major form.

This notebook is a replication of the Julia Academy's "Julia is fast" material, with some modification.
They gathered constructed there notebook from an MIT lecture given on the topic by Steven Johnson
(https://github.com/JuliaAcademy/Introduction-to-Julia/blob/main/9%20-%20Julia%20is%20fast.ipynb)
=#

using BenchmarkTools
using Libdl     # to parse a string as C
using PyCall
using Conda

# ---------------------- Benchmark Argument
a = rand(10^7)


# ---------------------- Julia declaration
function mysum(A)
    s = 0.0
    for a in A
        s += a
    end
    s
end

function mysum_simd(A)
    s = 0.0
    @simd for a in A
        s += a
    end
    s
end


# ---------------------- Python and Numpy declaration
# Our pyton implementation is rather strange, no one should ever be summing over
# a 'List' of floats. Rather use their array package or numpy.
numpy_sum = pyimport("numpy")["sum"]
pysum = pybuiltin("sum")
py"""
def py_sum(A):
    s = 0.0
    for v in A:
        s += v
    return s
"""
sum_py = py"py_sum"


# ---------------------- C declaration
C_code = """
#include <stddef.h>
double c_sum(size_t n, double *X) {
    double s = 0.0;
    for (size_t i = 0; i < n; ++i) {
        s += X[i];
    }
    return s;
}
"""

# create a temp dir & compile to a shared library by piping C_code to gcc w/ no optimization
const Clib = tempname()
open(`gcc -fPIC -msse3 -xc -shared -o $(Clib * "." * Libdl.dlext) -`, "w") do f
    print(f, C_code)
end
# define a Julia function that calls the C function:
c_sum(X::Array{Float64}) = ccall(("c_sum", Clib), Float64, (Csize_t, Ptr{Float64}), length(X), X)

# compile with -03 optimization
const Clib_O3 = tempname()
open(`gcc -fPIC -O3 -msse3 -xc -shared -o $(Clib_O3 * "." * Libdl.dlext) -`, "w") do f
    print(f, C_code)
end
c_sum_O3(X::Array{Float64}) = ccall(("c_sum", Clib_O3), Float64, (Csize_t, Ptr{Float64}), length(X), X)

# compile with -03 optimization and fast_math (uses SIMD vectorization)
const Clib_fastmath = tempname()
open(`gcc -fPIC -msse3 -xc -shared -Ofast -o $(Clib_fastmath * "." * Libdl.dlext) -`, "w") do f
    print(f, C_code)
end
c_sum_fastmath(X::Array{Float64}) = ccall(("c_sum", Clib_fastmath), Float64, (Csize_t, Ptr{Float64}), length(X), X)


# ---------------------- Compare Implementation Similarity
println("\nJulia sum() similar to C? ", sum(a) ≈ c_sum(a))
println("Julia sum() similar to C -O3? ", sum(a) ≈ c_sum_O3(a))
println("Julia sum() similar to C -Ofast? ", sum(a) ≈ c_sum_fastmath(a))
println("Julia sum() similar to Python built-in? ", sum(a) ≈ sum_py(a))
println("Julia sum() similar to Python user-defined? ", sum(a) ≈ numpy_sum(a))
println("Julia sum() similar to Julia user-defined? ", sum(a) ≈ mysum(a))
println("Julia sum() similar to Julia user-defined w/ SIMD? ", sum(a) ≈ mysum(a))

# ---------------------- Benchmark and Report
c_bench = @benchmark c_sum($a)
c_O3_bench = @benchmark $c_sum_O3($a)
c_fast_bench = @benchmark $c_sum_fastmath($a)
j_bench = @benchmark sum($a)
py_numpy_bench = @benchmark $numpy_sum($a)
py_list_bench = @benchmark $pysum($a)
py_hand = @benchmark $sum_py($a)
my_bench = @benchmark $mysum($a)
my_bench_simd = @benchmark $mysum_simd($a)


# Column sum
d = Dict()
d["C no flags"] = minimum(c_bench.times) / 1e6  # in milliseconds
d["C -O3"] = minimum(c_O3_bench.times) / 1e6
d["C -Ofast"] = minimum(c_fast_bench.times) / 1e6
d["Julia user-defined"] = minimum(my_bench.times) / 1e6
d["Julia user-defined SIMD"] = minimum(my_bench_simd.times) / 1e6
d["Julia built-in"] = minimum(j_bench.times) / 1e6
d["Python built-in"] = minimum(py_list_bench.times) / 1e6
d["Python user-defined"] = minimum(py_hand.times) / 1e6
d["Python numpy"] = minimum(py_numpy_bench.times) / 1e6

println("\nFastest time in milliseconds summing 10^7 elements:")
for (key, value) in sort(collect(d), by=last)
    println(rpad(key, 25, "."), lpad(round(value; digits=4), 11, "."))
end
