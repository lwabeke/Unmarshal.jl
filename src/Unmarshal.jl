module Unmarshal

# package code goes here

# Helper function
function prettyPrint(verboseLvl, str)
    tabs = ""
    for cntr=1:verboseLvl
        tabs = tabs * "\t"
    end
    println("$(tabs)$(str)")    
end


export unmarshal # returns a reconstructed variable from a JSON parsed string

"""

unmarshal(T, dict, verbose = false)

Reconstructs an object of Type T using the dictionary output of a JSON.parse.

Set verbose `true` to get debug information about how the data hierarchy is unmarshalled. This might be useful to track down parsing errors and/or mismatches between the JSON object and the Type definition.

#Example

```jldoctest
julia> using JSON

julia> var = randn(Float64, 5);  # Should work for most other variations of types you can think of

julia> unmarshal(typeof(var), JSON.parse(JSON.json(var)) ) == var
true
```

"""
function unmarshal(DT :: Type, parsedJson :: String, verbose :: Bool = false, verboseLvl :: Int = 0) 
    if (verbose)
        prettyPrint(verboseLvl, "$(DT) (String)")
        verboseLvl+=1
    end
	DT(parsedJson)
end

function unmarshal{E}(::Type{Vector{E}}, parsedJson::Vector, verbose :: Bool = false, verboseLvl :: Int = 0)
    if (verbose)
        prettyPrint(verboseLvl, "Vector{$E}")
        verboseLvl+=1
    end

    [(unmarshal(E, field, verbose, verboseLvl) for field in parsedJson)...]
end

unmarshal{E}(::Type{Array{E}}, xs::Vector, verbose :: Bool = false, verboseLvl :: Int = 0) = unmarshal(Vector{E}, xs, verbose, verboseLvl)

function unmarshal{E,N}(::Type{Array{E, N}}, parsedJson::Vector, verbose :: Bool = false, verboseLvl :: Int = 0)
    if (verbose)
        prettyPrint(verboseLvl, "Array{$E, $N}")
        verboseLvl+=1
    end

    cat(N, (unmarshal(Array{E,N-1}, x, verbose, verboseLvl) for x in parsedJson)...)
end


function unmarshal(DT :: Type, parsedJson :: Associative, verbose :: Bool = false, verboseLvl :: Int = 0)
    if (verbose)
            prettyPrint(verboseLvl, "$(DT) Associative")
        verboseLvl+=1
    end

    if !isleaftype(DT)
        throw(ArgumentError("Cannot unmarshal a non-leaf type $(DT) without a custom specialization"))
    end

    tup = ()
    for iter in fieldnames(DT)
        DTNext = fieldtype(DT,iter)
#        @show iter, DTNext, !haskey(parsedJson, string(iter)) 

        if !haskey(parsedJson, string(iter)) 
            try
            	val = DTNext()
            catch ex
            	if isa(ex, MethodError)
                    throw(ArgumentError("Key $(string(iter)) is missing from the structure $(DT) and field is not Nullable"))
               end
                rethrow(ex)
            end # try-cath
        else
            val = unmarshal( DTNext, parsedJson[string(iter)], verbose, verboseLvl)
        end
            
        tup = (tup..., val)
    end

    DT(tup...)
end

function unmarshal{T<:Tuple, N}(DT :: Type{T}, parsedJson :: Array{Any,N}, verbose :: Bool = false, verboseLvl :: Int = 0)
    if (verbose)
        prettyPrint(verboseLvl, "$(T) $(N) Dimensions, length $(length(parsedJson))")
        verboseLvl += 1
    end
    
    ((unmarshal(fieldtype(T,1), field, verbose, verboseLvl) for field in parsedJson)...)
end

unmarshal{T<:Number}(::Type{T}, x::Number, verbose :: Bool = false, verboseLvl :: Int = 0) = T(x)
unmarshal{T}(::Type{Nullable{T}}, x, verbose :: Bool = false, verboseLvl :: Int = 0) = Nullable(unmarshal(T, x))
unmarshal{T}(::Type{Nullable{T}}, x::Void, verbose :: Bool = false, verboseLvl :: Int = 0) = Nullable{T}()

unmarshal(T::Type, x, verbose :: Bool = false, verboseLvl :: Int = 0) =
    throw(ArgumentError("no unmarshal function defined to convert $(typeof(x)) to $(T); consider providing a specialization"))

end # module