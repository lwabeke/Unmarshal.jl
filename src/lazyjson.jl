
unmarshal( DT :: Type{String}, p :: LazyJSON.String{String}, verbose :: Bool = false, verboseLvl :: Int = 0) = String(p)

function unmarshal(DT :: Type{T}, parsedJson :: LazyJSON.Object{Nothing,String}, verbose :: Bool = false, verboseLvl :: Int = 0) where T <: Dict
    if verbose
        prettyPrint(verboseLvl, "$(DT) Dict from LazyJSON")
        verboseLvl += 1
    end
    val = DT()
    for iter in keys(parsedJson)
        if verbose
           prettyPrint(verboseLvl - 1, "\\--> $(iter) $(valtype(DT))")
        end
        tmp = unmarshal(valtype(DT), parsedJson[String(iter)], verbose, verboseLvl)
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

function unmarshal(DT :: Type{Pair{TF, TS}}, parsedJson :: LazyJSON.Object, verbose :: Bool = false, verboseLvl :: Int = 0) where {TF, TS}
    if verbose
          prettyPrint(verboseLvl, "Pair $(DT) AbstractDict")
          verboseLvl += 1
    end

    if (length(keys(parsedJson)) > 1)
          @warn "Expected a single pair, but found a multi-entry dictionary, just using the first key: $(collect(keys(parsedJson))[1])"
    end
    firstVal = (collect(keys(parsedJson))[1]) #, verbose, verboseLvl)
    secondVal = (parsedJson[String(firstVal)]) #, verbose, verboseLvl)
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

unmarshal(::Type{T}, x::Number, verbose :: Bool = false, verboseLvl :: Int = 0) where T <: Number = T(x)
unmarshal(::Type{Union{T,Nothing}}, x::LazyJSON.Number, verbose :: Bool = false, verboseLvl :: Int = 0) where T <: Number = T(x)
unmarshal(::Type{Nullable{T}}, x::LazyJSON.Number, verbose :: Bool = false, verboseLvl :: Int = 0) where T <: Number = Nullable(T(x))
unmarshal(::Type{Union{T,Missing}}, x::LazyJSON.Number, verbose :: Bool = false, verboseLvl :: Int = 0) where T <: Number= T(x)

