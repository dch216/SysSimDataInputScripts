if !isdefined(Main,:parsed_args)
  include("parse_args.jl")
end

using DataFrames, CSV, JLD2

begin
    nothing_to_do = true

    input_dir = parsed_args["input-path"] != nothing ? parsed_args["input-path"] : "inputs"
    input_filename = joinpath(input_dir,"KeplerMAST_TargetProperties.csv")
    output_dir = parsed_args["output-path"] != nothing ? parsed_args["output-path"] : "."
    output_filename = joinpath(output_dir, "KeplerMAST_TargetProperties.jld2")
    if !isfile(output_filename)
        @assert(isfile(joinpath(input_dir,"KeplerMAST_TargetProperties.csv")))
        target_properties = CSV.read(input_filename,allowmissing=:none)
        @save output_filename target_properties
        nothing_to_do = false
    end

    if nothing_to_do
        println("# " * output_filename * " is already on disk.")
    end

end # begin
