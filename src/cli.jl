#=
cli:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-02-26
=#

module Cli
using ArgParse

cli_parser = ArgParseSettings()
@add_arg_table! cli_parser begin
    "--scene"
    help = "scene filename"
    arg_type = String
    required = true
    "--output"
    help = "output filename"
    arg_type = String
    default = "output.png"
    "--camera"
    help = "camera name"
    arg_type = String
    default = ""
    "--addsky"
    help = "add sky"
    arg_type = Bool
    default = false
    "--envname"
    help = "add environment"
    arg_type = String
    default = ""
    "--resolution"
    help = "image resolution"
    arg_type = Int
    default = 1280
    "--samples"
    help = "number of samples"
    arg_type = Int
    default = 512
    "--bounces"
    help = "number of bounces"
    arg_type = Int
    default = 8
    "--denoise"
    help = "enable denoiser"
    arg_type = Bool
    default = false
    "--noparallel"
    help = "disable threading"
    arg_type = Bool
    default = false
    "--highqualitybvh"
    help = "enable high quality bvh"
    arg_type = Bool
    default = false
    "--envhidden"
    help = "hide environment"
    arg_type = Bool
    default = false
    "--tentfilter"
    help = "filter image"
    arg_type = Bool
    default = false
end
parse_cli_args() = parse_args(cli_parser)
end
