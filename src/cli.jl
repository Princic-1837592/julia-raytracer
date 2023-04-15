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
    "--sampler"
    help = "sampler type"
    arg_type = String
    default = "path"
    "--clamp"
    help = "clamp image"
    arg_type = Float32
    default = 10.0f0
    "--nocaustics"
    help = "disable caustics"
    arg_type = Bool
    default = false
    "--batch"
    help = "run samples in batches"
    arg_type = Int
    default = 1
    "--bvhstacksize"
    help = "max depth of bvh exploration"
    arg_type = Int
    default = 128
end

const SAMPLER_TYPES = ["path", "naive"]

mutable struct Params
    scene          :: String
    output         :: String
    camera         :: Any
    addsky         :: Bool
    envname        :: String
    resolution     :: Int
    samples        :: Int
    bounces        :: Int
    denoise        :: Bool
    noparallel     :: Bool
    highqualitybvh :: Bool
    envhidden      :: Bool
    tentfilter     :: Bool
    sampler        :: Int
    clamp          :: Int
    nocaustics     :: Bool
    batch          :: Int
    bvhstacksize   :: Int

    function Params(params)
        sidx = indexin([params["sampler"]], SAMPLER_TYPES)
        sampler = if sidx[1] == nothing
            1
        else
            sidx[1]
        end
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
            sampler,
            params["clamp"],
            params["nocaustics"],
            params["batch"],
            params["bvhstacksize"],
        )
    end
end

function parse_cli_args(args)
    params = parse_args(args, cli_parser)
    if params == nothing
        nothing
    else
        Params(params)
    end
end

end
