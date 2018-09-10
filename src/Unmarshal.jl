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

using JSON
import Missings: Missing, missing
import Nullables: Nullable

function unmarshal(DT :: Type, parsedJson :: String, verbose :: Bool = false, verboseLvl :: Int = 0)
    if (verbose)
        prettyPrint(verboseLvl, "$(DT) (String)")
        verboseLvl+=1
    end
    if DT <: Array
        [parsedJson]
    else
        DT(parsedJson)
    end
end

function unmarshal(::Type{Vector{E}}, parsedJson::Vector, verbose :: Bool = false, verboseLvl :: Int = 0) where E
    if (verbose)
        prettyPrint(verboseLvl, "Vector{$E}")
        verboseLvl+=1
    end

    [(unmarshal(E, field, verbose, verboseLvl) for field in parsedJson)...]
end

unmarshal(::Type{Array{E}}, xs::Vector, verbose :: Bool = false, verboseLvl :: Int = 0) where E = unmarshal(Vector{E}, xs, verbose, verboseLvl)

function unmarshal(::Type{Array{E, N}}, parsedJson::Vector, verbose :: Bool = false, verboseLvl :: Int = 0) where {E, N}
    if (verbose)
        prettyPrint(verboseLvl, "Array{$E, $N}")
        verboseLvl+=1
    end

    cat((unmarshal(Array{E,N-1}, x, verbose, verboseLvl) for x in parsedJson)..., dims=N)
end


"""
    unmarshal(T, dict[, verbose[, verboselvl]])

Reconstructs an object of Type T using the dictionary output of a `JSON.parse.`

Set verbose `true` to get debug information about how the data hierarchy is unmarshalled. This might be useful to track down parsing errors and/or mismatches between the JSON object and the Type definition.

# Example

```jldoctest
julia> using JSON

julia> var = randn(Float64, 5);  # Should work for most other variations of types you can think of

julia> unmarshal(typeof(var), JSON.parse(JSON.json(var)) ) == var
true
```

"""
function unmarshal(DT :: Type, parsedJson :: AbstractDict, verbose :: Bool = false, verboseLvl :: Int = 0)
    if (verbose)
            prettyPrint(verboseLvl, "$(DT) AbstractDict")
        verboseLvl+=1
    end

    if !isconcretetype(DT)
        throw(ArgumentError("Cannot unmarshal a non-leaf type $(DT) without a custom specialization"))
    end

    tup = ()
    for iter in fieldnames(DT)
        DTNext = fieldtype(DT,iter)
        if (verbose)
           prettyPrint(verboseLvl-1, "\\--> $(iter) <: $(DTNext) ")
        end

        if !haskey(parsedJson, string(iter)) 
            # check whether DTNext is compatible with any scheme for missing values
            val = if DTNext <: Nullable
                DTNext()
            elseif Missing <: DTNext
                missing
            elseif Nothing <: DTNext
                Nothing()
            else
                throw(ArgumentError("Key $(string(iter)) is missing from the structure $DT, and field is neither Nullable nor Missings nor Nothing-compatible"))
            end
        else
            val = unmarshal( DTNext, parsedJson[string(iter)], verbose, verboseLvl)
        end

        tup = (tup..., val)
    end

    DT(tup...)
end

function unmarshal(DT :: Type{T}, parsedJson :: Array{Any,N}, verbose :: Bool = false, verboseLvl :: Int = 0) where {T<:Tuple, N}
    if (verbose)
        prettyPrint(verboseLvl, "$(T) $(N) Dimensions, length $(length(parsedJson))")
        verboseLvl += 1
    end

    ((unmarshal(fieldtype(T,1), field, verbose, verboseLvl) for field in parsedJson)...,)
end

function unmarshal(DT :: Type{T}, parsedJson :: AbstractDict, verbose :: Bool = false, verboseLvl :: Int = 0) where T <: Dict
    if (verbose)
        prettyPrint(verboseLvl, "$(DT) Dict ")
        verboseLvl += 1
    end
    val = DT()
    for iter in keys(parsedJson)
        if (verbose)
           prettyPrint(verboseLvl-1, "\\--> $(iter) ")
        end
        tmp = unmarshal(valtype(DT), parsedJson[iter], verbose, verboseLvl) 
        if keytype(DT) <: AbstractString
            val[iter] = tmp 
        else
            try
                val[unmarshal(keytype(DT),JSON.parse(iter),verbose, verboseLvl)] = tmp # Use JSON.parse and Unmarshal to cast from type of iter to ketype(DT)
            catch ex
                val[keytype(DT)(iter)] = tmp  # Try direct casting, which will hopefully generate a readable enough exception error if it fails
            end
        end
    end
    val
end

unmarshal(::Type{T}, x::Number, verbose :: Bool = false, verboseLvl :: Int = 0) where T<:Number = T(x)
unmarshal(::Type{Nullable{T}}, x, verbose :: Bool = false, verboseLvl :: Int = 0) where T = Nullable(unmarshal(T, x))
unmarshal(::Type{Nullable{T}}, x::Nothing, verbose :: Bool = false, verboseLvl :: Int = 0) where T = Nullable{T}()
unmarshal(::Type{Union{T,Missing}}, x, verbose :: Bool = false, verboseLvl :: Int = 0) where T = unmarshal(T, x, verbose, verboseLvl)
unmarshal(::Type{Union{T,Nothing}}, x, verbose :: Bool = false, verboseLvl :: Int = 0) where T = unmarshal(T, x, verbose, verboseLvl)

unmarshal(T::Type, x, verbose :: Bool = false, verboseLvl :: Int = 0) =
    throw(ArgumentError("no unmarshal function defined to convert $(typeof(x)) to $(T); consider providing a specialization"))

#The following functions have been moved here to the end, since they appear to be unused by codecov. Consider deleting them unless actual use cases can be identified
function unmarshal(::Type{Vector{E}}, parsedJson::Number, verbose :: Bool = false, verboseLvl :: Int = 0) where E<:Number
    if (verbose)
        prettyPrint(verboseLvl, "Vector{$E}")
        verboseLvl+=1
    end

    [(unmarshal(E, field, verbose, verboseLvl) for field in parsedJson)...]
end

unmarshal(::Type{Array{E}}, xs::Number, verbose :: Bool = false, verboseLvl :: Int = 0) where E<:Number = unmarshal(Vector{E}, xs, verbose, verboseLvl)

function unmarshal(::Type{Array{E, N}}, parsedJson::Number, verbose :: Bool = false, verboseLvl :: Int = 0) where {E<:Number, N}
    if (verbose)
        prettyPrint(verboseLvl, "Array{$E, $N}")
        verboseLvl+=1
    end

    cat(E(parsedJson), dims=N)
end



end # module
