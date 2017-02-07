module Unmarshal

# package code goes here

export unmarshal # returns a reconstructed variable from a JSON parsed string
"""
Called with a given Type and using the dictionary output of a JSON.parse , it will try to reconstruct the Type from the JSON dictionary.

    unmarshal(T, dict)

    unmarshal(typeof(var), JSON.parse(JSON.json(var)) == var
"""

function unmarshal(DT :: Type, parsedJson :: String) 
#    @show "direct conversion from string"
	DT(parsedJson)
end

function unmarshal{E}(::Type{Vector{E}}, parsedJson::Vector)
    E[unmarshal(E, x) for x in parsedJson]
end
unmarshal{E}(::Type{Array{E}}, xs::Vector) = unmarshal(Vector{E}, xs)

function unmarshal{E,N}(::Type{Array{E, N}}, parsedJson::Vector)
    cat(N, (unmarshal(Array{E,N-1}, x) for x in parsedJson)...)
end


function unmarshal(DT :: Type, parsedJson :: Associative)
#    @show "unmarshalStruct"
    if !isleaftype(DT)
        throw(ArgumentError("Cannot unmarshal a non-leaf type without a custom specialization"))
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
            val = unmarshal( DTNext, parsedJson[string(iter)])
        end
            
        tup = (tup..., val)
    end

    DT(tup...)
end

unmarshal{T<:Number}(::Type{T}, x::Number) = T(x)
unmarshal{T}(::Type{Nullable{T}}, x) = Nullable(unmarshal(T, x))
unmarshal{T}(::Type{Nullable{T}}, x::Void) = Nullable{T}()

unmarshal(T::Type, x) =
    throw(ArgumentError("no unmarshal function defined to convert $(typeof(x)) to $(T); consider providing a specialization"))

end # module
