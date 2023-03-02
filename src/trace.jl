#=
trace:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-02-26
=#

module Trace

using ..Scene: SceneData
using ..Math: Vec3f, Vec4f
using ..Bvh: SceneBvh

struct TraceState
    width   :: Int32
    height  :: Int32
    samples :: Int32
    image   :: Array{Vec4f,1}
    albedo  :: Array{Vec3f,1}
    normal  :: Array{Vec3f,1}
    hits    :: Array{Int32,1}
    #  rngs       ::Array{rng_state}
    denoised::Array{Vec4f,1}

    TraceState(width, height, samples, image, albedo, normal, hits, denoised) =
        new(width, height, samples, image, albedo, normal, hits, denoised)
end

function make_trace_lights(scene::SceneData, params) end

function make_trace_state(scene::SceneData, params)::TraceState
    camera = scene.cameras[params["camera"]]
    if camera.aspect >= 1
        width  = params["resolution"]
        height = round(Int32, params["resolution"] / camera.aspect)
    else
        height = params["resolution"]
        width  = round(Int32, params["resolution"] * camera.aspect)
    end
    samples = 0
    image = Array{Vec4f}(undef, width * height)
    fill!(image, Vec4f(0, 0, 0, 0))
    albedo = Array{Vec3f}(undef, width * height)
    fill!(albedo, Vec3f(0, 0, 0))
    normal = Array{Vec3f}(undef, width * height)
    fill!(normal, Vec3f(0, 0, 0))
    hits = Array{Int32}(undef, width * height)
    fill!(hits, 0)
    denoised = Array{Vec4f}(undef, 0)
    if params["denoise"]
        denoised = Array{Vec4f}(undef, width * height)
        fill!(denoised, Vec4f(0, 0, 0, 0))
    end
    TraceState(width, height, samples, image, albedo, normal, hits, denoised)
end

function trace_samples(state::TraceState, scene::SceneData, bvh::SceneBvh, lights, params) end

end
