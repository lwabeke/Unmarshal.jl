module Unmarshal

# package code goes here

# Helper function
function prettyPrint(verboseLvl, str)
    tabs = ""
    for cntr = 1:verboseLvl
        tabs = tabs * "\t"
    end
    println("$(tabs)$(str)")
end


export unmarshal # returns a reconstructed variable from a JSON parsed string

using Requires

using JSON
import Missings: Missing, missing
import Nullables: Nullable

function __init__()
    @require LazyJSON="fc18253b-5e1b-504c-a4a2-9ece4944c004" include("lazyjson.jl")
end

unmarshal(::Type{Any}, x::String, verbose :: Bool = false, verboseLvl :: Int = 0) = x
unmarshal(::Type{Any}, x, verbose :: Bool = false, verboseLvl :: Int = 0) = x
function unmarshal(::Type{Any}, xs::Union{Vector{E}, AbstractArray}, verbose :: Bool = false, verboseLvl :: Int = 0) where E
    if verbose
        prettyPrint(verboseLvl, "Any{$(eltype(xs))}")
        prettyPrint(verboseLvl, "List")
        verboseLvl += 1
    end
    [(unmarshal(eltype(xs), x, verbose, verboseLvl) for x in xs)...]
end

function unmarshal(DT :: Type, parsedJson :: String, verbose :: Bool = false, verboseLvl :: Int = 0)
    if verbose
        prettyPrint(verboseLvl, "$(DT) (String)")
        verboseLvl += 1
    end
    DT(parsedJson)
end

function unmarshal(::Type{Vector{E}}, parsedJson::Union{Vector, AbstractArray}, verbose :: Bool = false, verboseLvl :: Int = 0) where E
    if verbose
        prettyPrint(verboseLvl, "Vector{$E}")
        verboseLvl += 1
    end

    [(unmarshal(E, field, verbose, verboseLvl) for field in parsedJson)...]
end

unmarshal(::Type{Array{E}}, xs::Union{Vector, AbstractArray}, verbose :: Bool = false, verboseLvl :: Int = 0) where E = unmarshal(Vector{E}, xs, verbose, verboseLvl)

function unmarshal(::Type{Array{E, N}}, parsedJson::Union{Vector, AbstractArray}, verbose :: Bool = false, verboseLvl :: Int = 0) where {E, N}
    if verbose
        prettyPrint(verboseLvl, "Array{$E, $N}")
        verboseLvl += 1
    end

    cat((unmarshal(Array{E,N-1}, x, verbose, verboseLvl) for x in parsedJson)..., dims=N)
end

unmarshal(::Type{Array{E, N} where E}, xs::Union{Vector, AbstractArray}, verbose :: Bool = false, verboseLvl :: Int = 0) where N = unmarshal(Array{Any, N}, xs, verbose, verboseLvl)
unmarshal(::Type{Array}, xs::Union{Vector,AbstractArray}, verbose :: Bool = false, verboseLvl :: Int = 0) where N = unmarshal(Vector{Any}, xs, verbose, verboseLvl)


"""
    unmarshal(T, dict[, verbose[, verboselvl]])

Reconstructs an object of Type T using the dictionary output of a `JSON.parse` or now 'LazyJSON.parse`.

Set verbose `true` to get debug information about how the data hierarchy is unmarshalled. This might be useful to track down parsing errors and/or mismatches between the JSON object and the Type definition.

# Example

```jldoctest
julia> using JSON

julia> var = randn(Float64, 5);  # Should work for most other variations of types you can think of

julia> unmarshal(typeof(var), JSON.parse(JSON.json(var)) ) == var
true
 
or 

julia> using LazyJSON

julia> var = randn(Float64, 5);  # Should work for most other variations of types you can think of

julia> unmarshal(typeof(var), LazyJSON.parse(JSON.json(var)) ) == var
true
```

"""
function unmarshal(DT :: Type, parsedJson :: AbstractDict, verbose :: Bool = false, verboseLvl :: Int = 0)
    if verbose
            prettyPrint(verboseLvl, "$(DT) AbstractDict")
        verboseLvl += 1
    end

    if !isconcretetype(DT)
        throw(ArgumentError("Cannot unmarshal a non-leaf type $(DT) without a custom specialization"))
    end

    tup = ()
    for iter in fieldnames(DT)
        DTNext = fieldtype(DT,iter)
        if verbose
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

function unmarshal(DT :: Type{Pair{TF, TS}}, parsedJson :: AbstractDict, verbose :: Bool = false, verboseLvl :: Int = 0) where {TF, TS}
    if verbose
          prettyPrint(verboseLvl, "Pair $(DT) AbstractDict")
          verboseLvl += 1
    end

    if (length(keys(parsedJson)) > 1)
          @warn "Expected a single pair, but found a multi-entry dictionary, just using the first key: $(collect(keys(parsedJson))[1])"
    end
    firstVal = (collect(keys(parsedJson))[1]) #, verbose, verboseLvl)
    secondVal = (parsedJson[firstVal]) #, verbose, verboseLvl)
#    @show firstVal, secondVal

    if !isa(firstVal, TF)
        try
           firstVal = TF(firstVal)
        catch ex
           firstVal = unmarshal(TF, JSON.parse(firstVal), verbose, verboseLvl)
        end
    end

    if !isa(secondVal, TS)
        try
           secondVal = TS(secondVal)
        catch ex
           throw(ArgumentError("Error trying to convert value $(secondVal) of type $(typeof(secondVal)) to a $(TS), please provide a conversion")) 
        end
    end 

#    @show firstVal, secondVal

    (firstVal => secondVal) 
end

function unmarshal(::Type{T}, parsedJson :: Union{Vector, AbstractArray}, verbose :: Bool = true, verboseLvl :: Int = 0) where {T <: Tuple}
    if verbose
        prettyPrint(verboseLvl, "Tuple: $T")
        verboseLvl += 1
    end
    len = length(parsedJson) # fallback value
    try
        # If we have concrete lengths, rather use data type and ignore length of JSON
        len = fieldcount(T)
    catch ex
        # If we do not have concrete lengths, use length of JSON
    end
    ((unmarshal(fieldtype(T, i), parsedJson[i], verbose, verboseLvl) for i in 1:len)...,)
end

function _unmarshal(::Type{T}, key :: Symbol, parsedJson :: AbstractDict, verbose :: Bool = false, verboseLvl :: Int = 0) where T
    if verbose
        prettyPrint(verboseLvl - 1, "\\--> $(key) ")
    end
    unmarshal(T, parsedJson[string(key)], verbose, verboseLvl)
end

function unmarshal(::Type{NamedTuple{NS, TS}}, parsedJson :: AbstractDict, verbose :: Bool = false, verboseLvl :: Int = 0) where {NS, TS}
    if verbose
        prettyPrint(verboseLvl, "NamedTuple{$NS,$TS}")
        verboseLvl += 1
    end

    NamedTuple{NS}(_unmarshal(T, key, parsedJson, verbose, verboseLvl) for (i, (T, key)) in enumerate(zip(TS.parameters, NS)))
end
unmarshal(::Type{NamedTuple{NS}}, parsedJson :: AbstractDict, verbose :: Bool = false, verboseLvl :: Int = 0) where NS = unmarshal(NamedTuple{NS, NTuple{length(NS), Any}}, parsedJson, verbose, verboseLvl)
unmarshal(::Type{NamedTuple}, parsedJson :: AbstractDict, verbose :: Bool = false, verboseLvl :: Int = 0) = unmarshal(NamedTuple{(Symbol.(keys(parsedJson))...,)}, parsedJson, verbose, verboseLvl)


function unmarshal(DT :: Type{T}, parsedJson :: AbstractDict, verbose :: Bool = false, verboseLvl :: Int = 0) where T <: Dict
    if verbose
        prettyPrint(verboseLvl, "$(DT) Dict ")
        verboseLvl += 1
    end
    val = DT()
    for iter in keys(parsedJson)
        if verbose
           prettyPrint(verboseLvl - 1, "\\--> $(iter) $(valtype(DT))")
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

unmarshal(::Type{T}, x::Number, verbose :: Bool = false, verboseLvl :: Int = 0) where T <: Number = T(x)
unmarshal(::Type{Nullable{T}}, x, verbose :: Bool = false, verboseLvl :: Int = 0) where T = Nullable(unmarshal(T, x))
unmarshal(::Type{Nullable{T}}, x::Nothing, verbose :: Bool = false, verboseLvl :: Int = 0) where T = Nullable{T}()
unmarshal(::Type{Union{T,Missing}}, x, verbose :: Bool = false, verboseLvl :: Int = 0) where T = unmarshal(T, x, verbose, verboseLvl)
unmarshal(::Type{Union{T,Nothing}}, x, verbose :: Bool = false, verboseLvl :: Int = 0) where T = unmarshal(T, x, verbose, verboseLvl)

unmarshal(T::Type, x, verbose :: Bool = false, verboseLvl :: Int = 0) =
    throw(ArgumentError("no unmarshal function defined to convert $(typeof(x)) to $(T); consider providing a specialization"))

end # module
