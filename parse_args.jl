if occursin(r"inputs$",pwd())
    @error("This script is to be run from the data directory (submodule SysSimData), not from the inputs directory.")
end
if occursin(r"scripts$",pwd())
    @error("This script is to be run from the data directory (submodule SysSimData), not from the scripts directory.")
end

using ArgParse
s = ArgParseSettings()
@add_arg_table s begin
    "--download-stellar-catalog"
        help = "Download stellar catalogs from NExScI"
        action = :store_true
    "--download-large-files"
        help = "Download particularly large files (e.g., one-sigma depth functions)"
        action = :store_true
    "--make-target-properties"
        help = "Make KeplerMAST_TargetProperties.jld2 from inputs/KeplerMAST_TargetProperties.csv"
        action = :store_true
   "--output-path"
        arg_type = String
        help = "Path for output files (default depends on file)"
    "--input-path"
        arg_type = String
        help = "Path for input files (default depends on file)"
    "--all"
        help = "Download and make everything"
        action = :store_true
end

parsed_args = parse_args(ARGS, s)
#@show parsed_args
