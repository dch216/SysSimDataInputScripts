using DataFrames,CSV,JLD2
data = CSV.read("dr25_koi_mcmc_quant.csv")
df = DataFrame(Dict(:kepoi_name=>data[:kepoi_name],
  :depth_mean=>data[:depth_mean],:depth_std=>data[:depth_std],
  :duration_mean=>data[:duration_mean],:duration_std=>data[:duration_std]))

num_quantiles = 99
quantile_list = range(1/(num_quantiles+1),stop=num_quantiles/(num_quantiles+1),length=num_quantiles)
depth_quantiles = Array{Float64,2}(undef,length(df[:depth_mean]),num_quantiles)
duration_quantiles = Array{Float64,2}(undef,length(df[:duration_mean]),num_quantiles)

for i in 1:num_quantiles
  depth_quantiles[:,i] .= data[Symbol("depth_q" * string(i))]
  duration_quantiles[:,i] .= data[Symbol("duration_q" * string(i))]
end

df[:depth_quantiles] =  [depth_quantiles[i,:] for i in 1:size(depth_quantiles,1)]
df[:duration_quantiles] =  [duration_quantiles[i,:] for i in 1:size(duration_quantiles,1)]

function interpolate(x_in::AbstractArray{T1}, y_in::AbstractArray{T2}, x::T1) where {T1<:Number, T2<:Number}
    @assert x_in[1] <= x <= x_in[2]
    ((x_in[2]-x)*y_in[1]+(x-x_in[1])*y_in[2]) / (x_in[2]-x_in[1])
end

function interp_quantile_list(x::AbstractArray{T,1},q::Real;
            quantile_list=1:length(x) ) where T<:Number
   @assert issorted(quantile_list)
   @assert length(x) == length(quantile_list)
   idx_hi = searchsortedfirst(quantile_list,q)
   idx_lo = idx_hi-1
   if idx_hi>length(x)
     return x[end]
   elseif idx_lo<1
       return x[1]
   elseif q==quantile_list[idx_hi]
     return x[idx_hi]
   end
    interpolate(view(quantile_list,idx_lo:idx_hi),view(x,idx_lo:idx_hi), q)
end

function interp_quantile_list(x::AbstractArray{T,2},q::Real;
   quantile_list=1:size(x,2) ) where T<:Number
   @assert issorted(quantile_list)
   @assert size(x,2) == length(quantile_list)
   idx_hi = searchsortedfirst(quantile_list,q)
   idx_lo = idx_hi-1
   if idx_hi>size(x,2)
     return x[:,end]
   elseif idx_lo<1
       return x[:,1]
   elseif q==quantile_list[idx_hi]
     return x[:,idx_hi]
   end
    map(i->interpolate(view(quantile_list,idx_lo:idx_hi),view(x,i,idx_lo:idx_hi), q),1:size(x,1))
end

q_hi = 0.5+0.34134
q_mid = 0.5
q_lo = 0.5-0.34134
df[:koi_depth_err1] =  interp_quantile_list(depth_quantiles,q_hi,quantile_list=quantile_list) .-interp_quantile_list(depth_quantiles,q_mid,quantile_list=quantile_list)
df[:koi_depth_err2] =  interp_quantile_list(depth_quantiles,q_mid,quantile_list=quantile_list).-interp_quantile_list(depth_quantiles,q_lo,quantile_list=quantile_list)
df[:koi_duration_err1] = interp_quantile_list(duration_quantiles,q_hi,quantile_list=quantile_list) .-interp_quantile_list(duration_quantiles,q_mid,quantile_list=quantile_list)
df[:koi_duration_err2] = interp_quantile_list(duration_quantiles,q_mid,quantile_list=quantile_list).-interp_quantile_list(duration_quantiles,q_lo,quantile_list=quantile_list)

#kois = CSV.read("q1_q17_dr25_koi.csv", header=157, allowmissing=:all)
koi = CSV.read("../SysSimDataInputs/q1_q17_dr25_koi.csv", comment="#", categorical=0.1)
deletecols!(koi,[:koi_depth_err1,:koi_depth_err2,:koi_duration_err1,:koi_duration_err2])
join(koi,df, on=:kepoi_name)

# TODO: Update planet properties to reflect updated stellar properties from Gaia

@save "q1_q17_dr25_koi.jld2" koi

# to load
# using DataFrames, Dates, JLD2, FileIO
# koi = load("q1_q17_dr25_koi.jld2")["koi"]
