#=
cli:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-02-26
=#

module Cli

using ArgParse: ArgParseSettings, @add_arg_table!, parse_args

cli_parser = ArgParseSettings()
@add_arg_table! cli_parser begin
    "--scene"
    help = "scene filename"
    arg_type = String
    required = true
    "--output"
    help = "output filename"
    arg_type = String
    default = "tests/test_scene.png"
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

mutable struct Params
    scene::String
    output::String
    camera::Any
    addsky::Bool
    envname::String
    resolution::Int
    samples::Int
    bounces::Int
    denoise::Bool
    noparallel::Bool
    highqualitybvh::Bool
    envhidden::Bool
    tentfilter::Bool

    function Params(
        scene::String;
        output = "tests/test_scene.png",
        camera = "",
        addsky = false,
        envname = "",
        resolution = 1280,
        samples = 512,
        bounces = 8,
        denoise = false,
        noparallel = false,
        highqualitybvh = false,
        envhidden = false,
        tentfilter = false,
    )
        new(
            scene,
            output,
            camera,
            addsky,
            envname,
            resolution,
            samples,
            bounces,
            denoise,
            noparallel,
            highqualitybvh,
            envhidden,
            tentfilter,
        )
    end

    function Params(params)
        new(
            params["scene"],
            params["output"],
            params["camera"],
            params["addsky"],
            params["envname"],
            params["resolution"],
            params["samples"],
            params["bounces"],
            params["denoise"],
            params["noparallel"],
            params["highqualitybvh"],
            params["envhidden"],
            params["tentfilter"],
        )
    end
end

function parse_cli_args(args)::Params
    params = parse_args(args, cli_parser)
    Params(params)
end

end
