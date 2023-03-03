#=
trace:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-02-26
=#

module Trace

using ..Scene: SceneData, CameraData, eval_camera
using ..Math: Vec2f, Vec3f, Vec4f, lerp, Vec2i
using ..Bvh: SceneBvh, intersect_scene_bvh
using ..Image: make_image, ImageData
using ..Geometry: Ray3f
using ..Sampling: sample_disk
using Printf: @printf

mutable struct TraceState
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
    camera = scene.cameras[params.camera]
    if camera.aspect >= 1
        width = params.resolution
        height = round(Int32, params.resolution / camera.aspect)
    else
        height = params.resolution
        width = round(Int32, params.resolution * camera.aspect)
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
    if params.denoise
        denoised = Array{Vec4f}(undef, width * height)
        fill!(denoised, Vec4f(0, 0, 0, 0))
    end
    TraceState(width, height, samples, image, albedo, normal, hits, denoised)
end

function trace_samples(state::TraceState, scene::SceneData, bvh::SceneBvh, lights, params)
    if state.samples >= params.samples
        return
    end
    if params.noparallel || true
        for i in 0:(state.height - 1)
            for j in 0:(state.width - 1)
                trace_sample(state, scene, bvh, lights, i, j, state.samples, params)
            end
        end
    else
        #todo
    end
    state.samples += 1
end

function trace_sample(
    state::TraceState,
    scene::SceneData,
    bvh::SceneBvh,
    lights,
    i,
    j,
    sample::Int32,
    params,
)
    camera = scene.cameras[params.camera]
    idx = state.width * i + j + 1
    #todo
    ray = sample_camera(
        camera,
        Vec2i(i, j),
        Vec2i(state.width, state.height),
        Vec2f(0, 0),
        Vec2f(0, 0),
        params.tentfilter,
    )
    #todo
    radiance, hit, albedo, normal = trace_naive(scene, bvh, lights, ray, params)
    #     @printf("%.5f %.5f %.5f\n", ray.o[1], ray.o[2], ray.o[3])
    #     @printf("%.5f %.5f %.5f\n", ray.d[1], ray.d[2], ray.d[3])
    #     @printf("%.5f %.5f\n", ray.tmin, ray.tmax)
    println(hit)
    if !all(isfinite.(radiance))
        radiance = Vec3f(0, 0, 0)
    end
    #todo? if clamp
    weight::Float32 = 1 / (sample + 1)
    if hit
        state.image[idx] =
            lerp(state.image[idx], Vec4f(radiance.x, radiance.y, radiance.z, 1), weight)
        state.albedo[idx] = lerp(state.albedo[idx], albedo, weight)
        state.normal[idx] = lerp(state.normal[idx], normal, weight)
        state.hits[idx] += 1
    elseif !params.envhidden && length(scene.environments) != 0
    else
        state.image[idx] = lerp(state.image[idx], Vec4f(0, 0, 0, 0), weight)
        state.albedo[idx] = lerp(state.albedo[idx], Vec3f(0, 0, 0), weight)
        state.normal[idx] = lerp(state.normal[idx], -ray.d, weight)
    end
end

function sample_camera(
    camera::CameraData,
    ij::Vec2i,
    image_size::Vec2i,
    puv::Vec2f,
    luv::Vec2f,
    tent::Bool,
)::Ray3f
    if !tent
        uv = Vec2f((ij[1] + puv[1]) / image_size[1], (ij[2] + puv[2]) / image_size[2])
        eval_camera(camera, uv, sample_disk(luv))
    else
        #todo
        nothing
    end
end

function get_image(state::TraceState)
    image = make_image(state.width, state.height, true)
    get_image(image, state)
    image
end

function get_image(image::ImageData, state::TraceState)
    image.width = state.width
    image.height = state.height
    if length(state.denoised) == 0
        image.data = state.image
    else
        image.data = state.denoised
    end
end

function trace_naive(
    scene::SceneData,
    bvh::SceneBvh,
    lights,
    ray::Ray3f,
    params,
)::Tuple{Vec3f,Bool,Vec3f,Vec3f}
    Vec3f(1, 1, 1),
    #todo find_any=false
    intersect_scene_bvh(bvh, scene, ray, true),
    Vec3f(0, 0, 0),
    Vec3f(0, 0, 0)
end

end
