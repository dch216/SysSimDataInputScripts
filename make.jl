include("parse_args.jl")

nothing_to_do = true

if parsed_args["download-stellar-catalog"] || parsed_args["all"]
   println("# Looking for Stellar Tables")
   include("download_stellar_tables.jl")
   nothing_to_do = false
end

if parsed_args["make-target-properties"] || parsed_args["all"]
   println("# Looking for Kepler Target Properites")
   include("make_target_properties.jl")
   nothing_to_do = false
end

if nothing_to_do
    println("# No actions requested.\n# Run 'julia scripts/make.jl -h' to see command line options.")
end
