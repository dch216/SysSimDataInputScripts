using DataFrames, CSV, JLD2
target_properties = CSV.read("KeplerMAST_TargetProperties.csv",allowmissing=:none)
@save "KeplerMAST_TargetProperties.jld2" target_properties
