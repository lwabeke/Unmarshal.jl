using Unmarshal
using Test
using JSON
using LazyJSON

# write your own tests here

# Unmarshal tests

println("Start testing with library JSON")
include("unmarshal.jl")
println("Done testing with library JSON")

println("Start testing with library LazyJSON")
include("unmarshalLazyJSON.jl")
println("Done testing with library LazyJSON")

