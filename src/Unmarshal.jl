module Unmarshal

# package code goes here

export unmarshal # returns a reconstrcuted variable from a JSON parsed string
"""
Called with a given DataType and using the dictionary output of a JSON.parse , it will try to reconstruct the DataType from the JSON dictionary.

    unmarshal(typeof(var), JSON.parse(JSON.json(var)) == var
"""
function unmarshal{T}(DT :: Type{Array{T}}, parsedJson)
    #    @show "unmarshalArrayComposite"

    tmp = DT(length(parsedJson))
    for cnt=1:length(parsedJson)
        tmp[cnt] = unmarshal(T, parsedJson[cnt])
    end
    tmp
end


function unmarshal{T <: Number}(DT :: Type{Array{T}}, parsedJson)
#    @show "unmarshalArrayNumber"
    map(T, parsedJson)
end

function unmarshal{T <: Number}(DT :: Type{Array{Complex{T}}}, parsedJson)
#        @show "unmarshalArrayComplex"
    tmp = DT(length(parsedJson))
    for cnt=1:length(parsedJson)
        tmp[cnt] = unmarshal(Complex{T}, parsedJson[cnt])
    end
    tmp    
end


function unmarshal{T}(DT :: Type{Array{T, 2}}, parsedJson)
#    @show "unmarshalArray2"

    sizes = (length(parsedJson[1]), length(parsedJson) )
    tmp = DT(sizes)
    for cnt=1:length(parsedJson)
        tmp[:, cnt] = unmarshal(Array{T}, parsedJson[cnt])
    end
        
    tmp
end


function unmarshal{T, N}(DT :: Type{Array{T, N}}, parsedJson)
#    @show "unmarshalArrayN"
    if N == 1
        # This gets called if type was defined as Array{T,1}, instead of Array{T}
        return unmarshal(Array{T}, parsedJson)
    end

    sizes = (length(parsedJson) )
    p = parsedJson[1]
    for cnt=2:N
        sizes = (length(p), sizes... )
        p = p[1]
        end
#    @show sizes
    tmp = DT(sizes...)
    subblocksize = prod(sizes[1:N-1])
    for cnt=1:length(parsedJson)
        tmp[(1+(cnt-1)*subblocksize):(cnt*subblocksize)] = unmarshal(Array{T, N-1}, parsedJson[cnt])
    end
        
    tmp
end


function unmarshal(DT, parsedJson)
#    @show "unmarshalStruct"

    tup = ()
    for iter in fieldnames(DT)
        DTNext = fieldtype(DT,iter)
#        @show iter, DTNext, !haskey(parsedJson, string(iter)) 

        if !haskey(parsedJson, string(iter)) 
            try
            	val = DTNext()
            catch ex
            	if isa(ex, MethodError)
			error("Key $(string(iter)) is missing from the structure $(DT) and field is not Nullable")
               end
                rethrow(ex)
            end # try-cath
        else
            if (DTNext <: Array) || (typeof(parsedJson[string(iter)]) <: Dict{String,Any})
                val = unmarshal( DTNext, parsedJson[string(iter)])
            else
        #      @show parsedJson[string(iter)] 
                try
                	val = DTNext(parsedJson[string(iter)])
                catch ex
                	if isa(ex, MethodError)
				error("Cannot construct $(DTNext)($(parsedJson[string(iter)])). Type $(DT) might be not be concrete. Consider implementing overload function unmarshal(T ::$(DT), dict) to return a value of type $(DT)") 
                        end
			rethrow(ex)
                end # try-cath
            end
        end
            
        tup = (tup..., val)
    end
    
    DT(tup...)
end




end # module
