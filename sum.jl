#=
This script benchmarks the operation of summing over a row vector and column
vector. This file is based upon the Julia Acadamey Lecture titled, "Julia is fast"
which was built upon material from Steven Johnson's MIT lecture,
(https://github.com/stevengj/18S096/blob/master/lectures/lecture1/Boxes-and-registers) 
=#

using BenchmarkTools
using Libdl     # to parse a string as C
using PyCall
using Conda

# Define benchmark arguments
a = rand(10^7, 1)
b = rand(1, 10^7)

# ---------------------- Python and Numpy declaration
numpy_sum = pyimport("numpy")["sum"]
pysum = pybuiltin("sum")
py"""
def py_sum(A):
    s = 0.0
    for a in A:
        s += a
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
const Clib_03 = tempname()
open(`gcc -fPIC -O3 -msse3 -xc -shared -o $(Clib_03 * "." * Libdl.dlext) -`, "w") do f
    print(f, C_code)
end
c_sum_O3(X::Array{Float64}) = ccall(("c_sum", Clib_fastmath), Float64, (Csize_t, Ptr{Float64}), length(X), X)

# compile with -03 optimization and fast_math (uses SIMD vectorization)
const Clib_fastmath = tempname()
open(`gcc -fPIC -msse3 -xc -shared -Ofast -o $(Clib_fastmath * "." * Libdl.dlext) -`, "w") do f
    print(f, C_code)
end
c_sum_fastmath(X::Array{Float64}) = ccall(("c_sum", Clib_fastmath), Float64, (Csize_t, Ptr{Float64}), length(X), X)

# ---------------------- Compare Similarity
println("\nJulia sum() similar to C? ", sum(a) ≈ c_sum(a))
println("Julia sum() similar to C -O3? ", sum(a) ≈ c_sum(a))
println("Julia sum() similar to C -Ofast? ", sum(a) ≈ c_sum(a))
println("Julia sum() similar to Python built-in? ", sum(a) ≈ c_sum(a))
println("Julia sum() similar to Python user-defined? ", sum(a) ≈ c_sum(a))
println("Julia sum() similar to Numpy version? ", numpy_sum(a) ≈ sum(a), '\n')

# ---------------------- Benchmark and Report
c_bench = @benchmark c_sum($a)
c_O3_bench = @benchmark $c_sum_O3($a)
c_fast_bench = @benchmark $c_sum_fastmath($a)
j_bench = @benchmark sum($a)
py_numpy_bench = @benchmark $numpy_sum($a)
py_list_bench = @benchmark $pysum($a)
py_hand = @benchmark $sum_py($a)

# Column sum
d = Dict()
d["C no flags"] = minimum(c_bench.times) / 1e6  # in milliseconds
d["C -O3"] = minimum(c_O3_bench.times) / 1e6
d["C -Ofast"] = minimum(c_fast_bench.times) / 1e6
d["Julia built-in"] = minimum(j_bench.times) / 1e6
d["Python built-in"] = minimum(py_list_bench.times) / 1e6
d["Python user-defined"] = minimum(py_hand.times) / 1e6
d["Python numpy"] = minimum(py_numpy_bench.times) / 1e6

println("Column sum results")
for (key, value) in sort(collect(d), by=last)
    println(rpad(key, 25, "."), lpad(round(value; digits=4), 11, "."))
end


c_bench_col = @benchmark c_sum($b)
c_O3_bench = @benchmark $c_sum_O3($b)
c_fast_bench = @benchmark $c_sum_fastmath($b)
j_bench = @benchmark sum($b)
py_numpy_bench = @benchmark $numpy_sum($b)
py_list_bench = @benchmark $pysum($b)
py_hand = @benchmark $sum_py($b)


# rom sum
d["C no flags"] = minimum(c_bench.times) / 1e6  # in milliseconds
d["C -O3"] = minimum(c_O3_bench.times) / 1e6
d["C -Ofast"] = minimum(c_fast_bench.times) / 1e6
d["Julia built-in"] = minimum(j_bench.times) / 1e6
d["Python built-in"] = minimum(py_list_bench.times) / 1e6
d["Python user-defined"] = minimum(py_hand.times) / 1e6
d["Python numpy"] = minimum(py_numpy_bench.times) / 1e6

println("Row sum results")
for (key, value) in sort(collect(d), by=last)
    println(rpad(key, 25, "."), lpad(round(value; digits=4), 11, "."))
end
