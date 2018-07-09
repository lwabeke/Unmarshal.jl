# Unmarshal
### Unmarshalling parsed format dictionaries into Julia Objects

[![Build Status](https://travis-ci.org/lwabeke/Unmarshal.jl.svg?branch=master)](https://travis-ci.org/lwabeke/Unmarshal.jl)

[![Coverage Status](https://coveralls.io/repos/lwabeke/Unmarshal.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/lwabeke/Unmarshal.jl?branch=master)

[![codecov.io](http://codecov.io/github/lwabeke/Unmarshal.jl/coverage.svg?branch=master)](http://codecov.io/github/lwabeke/Unmarshal.jl?branch=master)


**Installation**: `pkg> add Unmarshal`


## Basic Usage

This package has currently only been tested with unmarshalling of JSON objects, but the intention is to in future also test it for working on other data formats.

```julia
import Unmarshal

using JSON

input = "{ \"bar\": { \"baz\": 17 }, \"foo\": 3.14 }"

struct Bar
    baz::Int
end

struct Foo
    bar::Bar
end

Unmarshal.unmarshal(Foo, JSON.parse(input))
# Foo(Bar(17))
jstring = JSON.json(ones(Float64, 3))
#"[1.0,1.0,1.0]"

Unmarshal.unmarshal(Array{Float64}, JSON.parse(jstring))
#3-element Array{Float64,1}:
# [ 1.0 ; 1.0 ; 1.0 ]
```

## Documentation

```julia
Unmarshal.unmarshal(MyType, parseOutput, verbose = false )
```
Builds on object of type :MyType from the dictionary produced by JSON.parse. Set verbose to true to get debug information about the type hierarchy beging unmarshalled. This might be useful in tracking down mismatches between the JSON object and the Julia type definition.


