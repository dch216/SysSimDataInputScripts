using HDF5, DataFrames, CSV, JLD2
using StatsBase, Polynomials, CurveFit
using PyPlot

kep_filename = joinpath(abspath(joinpath(dirname(Base.find_package("ExoplanetsSysSim")),"..")), "data\\inputs", "q1_q17_dr25_stellar.csv")
gaia_filename = joinpath(abspath(joinpath(dirname(Base.find_package("ExoplanetsSysSim")),"..")), "data\\inputs", "gaiadr2_keplerdr25_crossref.csv")
mast_filename = joinpath(abspath(joinpath(dirname(Base.find_package("ExoplanetsSysSim")),"..")), "data\\inputs", "KeplerMAST_TargetProperties.csv")
stellar_catalog_file_out = joinpath(abspath(joinpath(dirname(Base.find_package("ExoplanetsSysSim")),"..")), "data", "q1q17_dr25_gaia_fgk.jld2")

kep_df = CSV.read(kep_filename)
gaia_df = CSV.read(gaia_filename)
mast_df = CSV.read(mast_filename)

dup_gaiaid = findall(nonunique(DataFrame(x = gaia_df[!,:source_id])))
gaiaid_keep = trues(size(gaia_df,1))
gaiaid_keep[dup_gaiaid] .= false
gaia_df = gaia_df[gaiaid_keep,:]

println("Total crossref target stars = ", length(gaia_df[!,:kepid]))

mag_diff = gaia_df[!,:phot_g_mean_mag].-gaia_df[!,:kepmag]
quant_arr = quantile(mag_diff, [0.067,0.933])   # 1.5-sigma cut
mag_match = findall(x->quant_arr[1]<=x<=quant_arr[2], mag_diff)
gaia_df = gaia_df[mag_match,:]

gaia_col = [:kepid,:source_id,:parallax,:parallax_error,:astrometric_gof_al,:astrometric_excess_noise_sig,:phot_g_mean_mag,:bp_rp,:a_g_val,:priam_flags,:teff_val,:teff_percentile_lower,:teff_percentile_upper,:radius_val,:radius_percentile_lower,:radius_percentile_upper,:lum_val,:lum_percentile_lower,:lum_percentile_upper]
df = join(kep_df, gaia_df[!,gaia_col], on=:kepid)
df = join(df, mast_df, on=:kepid)
kep_df = nothing
gaia_df = nothing

println("Total target stars (KOIs) matching magnitude = ", length(df[!,:kepid]), " (", sum(df[!,:nkoi]),")")

df[!,:teff] = df[!,:teff_val]
df[!,:teff_err1] = df[!,:teff_percentile_upper].-df[!,:teff_val]
df[!,:teff_err2] = df[!,:teff_percentile_lower].-df[!,:teff_val]
select!(df, Not([:teff_val,:teff_percentile_upper,:teff_percentile_lower]))
df[!,:radius_err1] = df[!,:radius_percentile_upper].-df[!,:radius_val]
df[!,:radius_err2] = df[!,:radius_percentile_lower].-df[!,:radius_val]
df[!,:radius] = df[!,:radius_val]
select!(df, Not([:radius_val,:radius_percentile_upper,:radius_percentile_lower]))

not_binary_suspect = (df[!,:astrometric_gof_al] .<= 20) .& (df[!,:astrometric_excess_noise_sig] .<= 5)
astrometry_good = []
for x in 1:length(df[!,:kepid])
    if !(ismissing(df[x,:priam_flags]))
        pflag = string(df[x,:priam_flags])
         if (pflag[2] == '0') & (pflag[3] == '0') # WARNING: Assumes flag had first '0' removed by crossref script
             push!(astrometry_good, true)
         else
             push!(astrometry_good, false)
         end
     else
         push!(astrometry_good, false)
     end
end
astrometry_good = astrometry_good .& (df[!,:parallax_error] .< 0.1*df[!,:parallax])
# planet_search = df[!,:kepmag] .<= 16.

has_mass = .! (ismissing.(df[!,:mass]) .| ismissing.(df[!,:mass_err1]) .| ismissing.(df[!,:mass_err2]))
has_radius = .! (ismissing.(df[!,:radius]) .| ismissing.(df[!,:radius_err1]) .| ismissing.(df[!,:radius_err2]))
#has_dens = .! (ismissing.(df[!,:dens]) .| ismissing.(df[!,:dens_err1]) .| ismissing.(df[!,:dens_err2]))
has_cdpp = .! (ismissing.(df[!,:rrmscdpp01p5]) .| ismissing.(df[!,:rrmscdpp02p0]) .| ismissing.(df[!,:rrmscdpp02p5]) .| ismissing.(df[!,:rrmscdpp03p0]) .| ismissing.(df[!,:rrmscdpp03p5]) .| ismissing.(df[!,:rrmscdpp04p5]) .| ismissing.(df[!,:rrmscdpp05p0]) .| ismissing.(df[!,:rrmscdpp06p0]) .| ismissing.(df[!,:rrmscdpp07p5]) .| ismissing.(df[!,:rrmscdpp09p0]) .| ismissing.(df[!,:rrmscdpp10p5]) .| ismissing.(df[!,:rrmscdpp12p0]) .| ismissing.(df[!,:rrmscdpp12p5]) .| ismissing.(df[!,:rrmscdpp15p0]))
has_rest = .! (ismissing.(df[!,:dataspan]) .| ismissing.(df[!,:dutycycle]))
has_limbd = .! (ismissing.(df[!,:limbdark_coeff1]) .| ismissing.(df[!,:limbdark_coeff2]) .| ismissing.(df[!,:limbdark_coeff3]) .| ismissing.(df[!,:limbdark_coeff4]))

mast_cut =.&(df[!,:numLCEXqtrs].>0,df[!,:numLCqtrs].>4)

is_usable = .&(has_radius, has_mass, has_rest, has_cdpp, mast_cut, astrometry_good, not_binary_suspect)

df = df[findall(is_usable),:]
println("Total stars (KOIs) with valid parameters = ", length(df[!,:kepid]), " (", sum(df[!,:nkoi]),")")

fgk_color = (0.5 .<= df[!,:bp_rp] .<= 1.7)
# FGK = find(fgk_color)
df = df[findall(fgk_color),:]
near_FGK_MS = []
coeff = [2.5,-3.6,0.9]
for i in 1:6
    global near_FGK_MS = (log10.(df[!,:lum_val]).< map(x->polyval(Poly(coeff),x),df[!,:bp_rp]) .+ log10(1.75))
    global coeff = poly_fit(df[near_FGK_MS,:bp_rp],log10.(df[near_FGK_MS,:lum_val]),2)
end
FGK = findall(near_FGK_MS)

println("Total FGK stars (KOIs) with valid parameters = ", length(FGK), " (", sum(df[FGK, :nkoi]),")")

plot_samp = sample(1:length(df[!,:kepid]), 5000, replace=false)
FGK_samp = sample(FGK, 5000, replace=false)
plt[:scatter](df[FGK_samp, :bp_rp], m_absg[FGK_samp], s=3, label = "FGK", color="red")
plt[:scatter](df[plot_samp, :bp_rp], m_absg[plot_samp], s=3, label = "All", color="black")

plt[:ylabel](L"$M_G$")
plt[:xlabel](L"$B_p - R_p$")
plt[:ylim](reverse(plt[:ylim]()))
plt[:legend]()
#plt[:savefig]("fgk-dwarf_samp.png")

# See options at: http://exoplanetarchive.ipac.caltech.edu/docs/API_keplerstellar_columns.html
# TODO SCI DETAIL or IMPORTANT?: Read in all CDPP's, so can interpolate?
symbols_to_keep = [ :kepid, :source_id, :mass, :mass_err1, :mass_err2, :radius, :radius_err1, :radius_err2, :dens, :dens_err1, :dens_err2, :teff, :bp_rp, :lum_val, :rrmscdpp01p5, :rrmscdpp02p0, :rrmscdpp02p5, :rrmscdpp03p0, :rrmscdpp03p5, :rrmscdpp04p5, :rrmscdpp05p0, :rrmscdpp06p0, :rrmscdpp07p5, :rrmscdpp09p0, :rrmscdpp10p5, :rrmscdpp12p0, :rrmscdpp12p5, :rrmscdpp15p0, :dataspan, :dutycycle, :limbdark_coeff1, :limbdark_coeff2, :limbdark_coeff3, :limbdark_coeff4, :contam]
# delete!(df, [~(x in symbols_to_keep) for x in names(df)])    # delete columns that we won't be using anyway
df = df[FGK, symbols_to_keep]
tmp_df = DataFrame()
for col in names(df)
    tmp_df[!,col] = collect(skipmissing(df[!,col]))
end
df = tmp_df

save(stellar_catalog_file_out,"stellar_catalog", df)
