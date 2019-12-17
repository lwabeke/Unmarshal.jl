using Unmarshal
using JSON
#import Missings: Missing, missing
using Nullables
using LinearAlgebra

using Test
import Base.==

#Tests for various type of composite structures, including Nullables
input = "{ \"bar\": { \"baz\": 17 }, \"foo\": 3.14 }"
input2 = "{ \"bar\": { \"baz\": 17 }, \"foot\": 3.14 }"

struct Bar
    baz::Int
end

struct Foo
    bar::Bar
end

struct BazNothing
    foo::Union{Nothing,Float64}
    bar::Bar
end

struct BazMissing
    foo::Union{Missing,Float64}
    bar::Bar
end

struct BazNullable
    foo::Nullables.Nullable{Float64}
    bar::Bar
end

struct Qux
    baz::Union{Nothing,String}
    bar::Bar
    foo::Union{Nothing,Float64}
    missingfield::Union{Nothing,String}
end


@test Unmarshal.unmarshal(Foo, JSON.parse(input)) === Foo(Bar(17))
@test Unmarshal.unmarshal(BazNothing, JSON.parse(input)) === BazNothing(3.14, Bar(17))
@test Unmarshal.unmarshal(BazMissing, JSON.parse(input)) === BazMissing(3.14, Bar(17))
@test Unmarshal.unmarshal(BazNullable, JSON.parse(input)) === BazNullable(3.14, Bar(17))
@test Unmarshal.unmarshal(BazNothing, JSON.parse(input2)) === BazNothing(nothing, Bar(17))
@test Unmarshal.unmarshal(BazMissing, JSON.parse(input2)) === BazMissing(missing, Bar(17))
@show Unmarshal.unmarshal(BazNullable, JSON.parse(input2)) === BazNullable(Nullable{Float64}(), Bar(17))
@test Unmarshal.unmarshal(Qux, JSON.parse(input)) === Qux(Nothing(),Bar(17),3.14,Nothing())
@test_throws ArgumentError Unmarshal.unmarshal(Bar, JSON.parse(input))

#Test for handling of 1-D arrays
@test Unmarshal.unmarshal(Array{Float64,1}, ones(10), true) == ones(10)

#Test for structures of handling 1-D arrays
mutable struct StructOfArrays
    a1 :: Array{Float32, 1}
    a2 :: Array{Int, 1}
end

function ==(A :: StructOfArrays, B :: StructOfArrays)
    A.a1 == B.a1 && A.a2 == B.a2
end

tmp = StructOfArrays([0,1,2], [1,2,3])
jstring = JSON.json(tmp)
@test Unmarshal.unmarshal(StructOfArrays, JSON.parse(jstring)) == tmp

#Test for handling 2-D arrays
mutable struct StructOfArrays2D
    a3 :: Array{Float64, 2}
    a4 :: Array{Int, 2}
end

function ==(A :: StructOfArrays2D, B :: StructOfArrays2D)
    A.a3 == B.a3 && A.a4 == B.a4
end

tmp2 = StructOfArrays2D(ones(Float64, 2, 3), Matrix{Int}(I, 2, 3))
jstring = JSON.json(tmp2)
@test Unmarshal.unmarshal(StructOfArrays2D, JSON.parse(jstring))  == tmp2

#Test for handling N-D arrays
tmp3 = randn(Float64, 2, 3, 4)
jstring = JSON.json(tmp3)
@test Unmarshal.unmarshal(Array{Float64, 3}, JSON.parse(jstring))  == tmp3

#Test for handling arrays of composite entities
tmp4 = Array{Array{Int,2}}(undef, 2)

tmp4[1] = ones(Int, 3, 4)
tmp4[2] = zeros(Int, 1, 2)
tmp4
jstring = JSON.json(tmp4)
@test Unmarshal.unmarshal(Array{Array{Int,2}}, JSON.parse(jstring)) == tmp4

# Test to check handling of complex numbers
tmp5 = zeros(Float32, 2) + 1im * ones(Float32, 2)
jstring = JSON.json(tmp5)
@test Unmarshal.unmarshal(Array{Complex{Float32}}, JSON.parse(jstring)) == tmp5

tmp6 = zeros(Float32, 2, 2) + 1im * ones(Float32, 2, 2)
jstring = JSON.json(tmp6)
@test Unmarshal.unmarshal(Array{Complex{Float32},2}, JSON.parse(jstring)) == tmp6

# Test to see handling of abstract types
mutable struct reconfigurable{T}
    x :: T
    y :: T
    z :: Int
end

function ==(A :: reconfigurable{T1}, B :: reconfigurable{T2}) where {T1, T2}
    T1 == T2 && A.x == B.x && A.y == B.y && A.z == B.z
end


mutable struct higherlayer
    val :: reconfigurable
end

val = reconfigurable(1.0, 2.0, 3)
jstring = JSON.json(val)
@test Unmarshal.unmarshal(reconfigurable{Float64}, JSON.parse(jstring)) == reconfigurable{Float64}(1.0, 2.0, 3)

higher = higherlayer(val)
jstring = JSON.json(higher)
@test_throws ArgumentError Unmarshal.unmarshal(higherlayer, JSON.parse(jstring))

# Test string pass through
@test Unmarshal.unmarshal(String, JSON.parse(json("Test"))) == "Test"

# Test the verbose option
@test Unmarshal.unmarshal(Foo, JSON.parse(input), true) === Foo(Bar(17))
jstring = JSON.json(tmp3)
@test Unmarshal.unmarshal(Array{Float64, 3}, JSON.parse(jstring), true)  == tmp3

@test Unmarshal.unmarshal(String, JSON.parse(json("Test")), true) == "Test"

# Added test cases to attempt getting 100% code coverage
@test isequal(unmarshal(Nullable{Int64}, Nothing()), Nullable{Int64}())

@test_throws ArgumentError unmarshal(Nullable{Int64}, ones(Float64, 1))

# Test handling of Any
@test Unmarshal.unmarshal(Any, [1, 2]) == [1, 2]
@test Unmarshal.unmarshal(Any, [1, 2], true) == [1, 2]

# Test handling of Tuples
testTuples = ((1.0, 2.0, 3.0, 4.0), (2.0, 3.0))
jstring = JSON.json(testTuples)
jparsed = JSON.parse(jstring)
# Tuple of Arrays
tupleResult = (([testElement...] for testElement in testTuples)...,)
for typ in (Tuple, Tuple{Vararg{Array}}, Tuple{Array, Array})
    @test Unmarshal.unmarshal(typ, jparsed) == tupleResult
end
# Tuple of Tuples
for typ in (Tuple{Vararg{Tuple}}, Tuple{Vararg{Tuple{Vararg{Float64}}}})
    @test Unmarshal.unmarshal(typ, jparsed) == testTuples
end
# Array of Arrays
@test Unmarshal.unmarshal(Array{Array{Float64}}, JSON.parse(jstring)) == [([testElement...] for testElement in testTuples)...]

struct TupleTest
    a::Tuple
    b::Tuple{Int64, Float64}
    c::Tuple{Float64, Vararg{Int64}}
    d::NamedTuple{(:x, :y)}
    e::NamedTuple{(:x, :y), Tuple{Int64, Float64}}
end
testTuples = TupleTest(
    ("a", 1, 5),
    (5, 3.5),
    (1.2, 6, 7, 3),
    (x = 5, y = 9),
    (x = 3, y = 1.4),
)
jstring = JSON.json(testTuples)
@test Unmarshal.unmarshal(TupleTest, JSON.parse(jstring)) == testTuples
@test Unmarshal.unmarshal(TupleTest, JSON.parse(jstring), true) == testTuples

testNamedTuple = (x = 5, y = 9, z = "z")
jstring = JSON.json(testNamedTuple)
resultNamedTuple = Unmarshal.unmarshal(NamedTuple, JSON.parse(jstring))
@test all(getfield(testNamedTuple, key) == getfield(resultNamedTuple, key) for key in keys(testNamedTuple))

mutable struct DictTest
    testDict::Dict{Int, String}
end

function ==(D1 :: DictTest, D2 :: DictTest)
    for iter in keys(D1.testDict)
        if !(D1.testDict[iter] == D2.testDict[iter])
          return false
        end
    end
    for iter in keys(D2.testDict)
        if !(D1.testDict[iter] == D2.testDict[iter])
          return false
        end
    end

    true
end

dictTest = DictTest(Dict{Int, String}(1 => "Test1", 2 => "Test2"))

#@show JSON.json(dictTest)
#@show JSON.parse(JSON.json(dictTest))
@test Unmarshal.unmarshal(DictTest, JSON.parse(JSON.json(dictTest)),true) == dictTest


@show dictTest2 = Dict("k"=>"val")
@test Unmarshal.unmarshal(typeof(dictTest2), JSON.parse(JSON.json(dictTest2)), true) == dictTest2

mutable struct TestUnmarshal
    a::String
    b::String
    links::Dict{String, String}
end

function ==(T1 :: TestUnmarshal, T2 :: TestUnmarshal)
    T1.a == T2.a && T1.b == T2.b && T1.links == T2.links
end

raw = "{\"a\": \"\",\"b\": \"Test\",\"links\": {\"self\": \"TestDict\"}}"
j = JSON.parse(raw)
@show Unmarshal.unmarshal(TestUnmarshal, j) 
@test Unmarshal.unmarshal(TestUnmarshal, j) == TestUnmarshal("", "Test", Dict("self"=>"TestDict"))
t = TestUnmarshal("", "Test", Dict("self"=>"TestDict"))
@test Unmarshal.unmarshal(TestUnmarshal, JSON.parse(JSON.json(t))) == t

println("Starting tests on Pairs")
#Tests for pairs
p = ("3" => "7")
#@show p
@test Unmarshal.unmarshal(typeof(p), JSON.parse(JSON.json(p)), true) == p

p = (32 => 72)
#@show p
@test Unmarshal.unmarshal(typeof(p), JSON.parse(JSON.json(p)), true) == p


p = ("33" => 73)
#@show p
@test Unmarshal.unmarshal(typeof(p), JSON.parse(JSON.json(p)), true) == p

p = (34 => "74")
#@show p
@test Unmarshal.unmarshal(typeof(p), JSON.parse(JSON.json(p)), true) == p

p = (34 => ones(10))
#@show p
@test Unmarshal.unmarshal(typeof(p), JSON.parse(JSON.json(p)), true) == p
g=Unmarshal.unmarshal(typeof(p), JSON.parse(JSON.json(p)), true)
@show g

