#=
trace:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-02-26
=#

module Trace

using ..Scene:
    SceneData,
    CameraData,
    eval_camera,
    eval_shading_position,
    eval_shading_normal,
    eval_material,
    eval_environment,
    MaterialPoint
using ..Math: Vec2f, Vec3f, Vec4f, lerp, Vec2i, dot
using ..Bvh: SceneBvh, intersect_scene_bvh
using ..Image: make_image, ImageData
using ..Geometry: Ray3f
using ..Sampling: sample_disk, rand1f, rand2f
using Printf: @printf

mutable struct TraceState
    width   :: Int
    height  :: Int
    samples :: Int
    image   :: Vector{Vec4f}
    albedo  :: Vector{Vec3f}
    normal  :: Vector{Vec3f}
    hits    :: Vector{Int}
    #  rngs       ::Array{rng_state}
    denoised::Vector{Vec4f}

    TraceState(width, height, samples, image, albedo, normal, hits, denoised) =
        new(width, height, samples, image, albedo, normal, hits, denoised)
end

function make_trace_lights(scene::SceneData, params) end

function make_trace_state(scene::SceneData, params)::TraceState
    camera = scene.cameras[params.camera]
    if camera.aspect >= 1
        width = params.resolution
        height = round(Int, params.resolution / camera.aspect)
    else
        height = params.resolution
        width = round(Int, params.resolution * camera.aspect)
    end
    samples = 0
    image = Vector{Vec4f}(undef, width * height)
    fill!(image, Vec4f(0, 0, 0, 0))
    albedo = Vector{Vec3f}(undef, width * height)
    fill!(albedo, Vec3f(0, 0, 0))
    normal = Vector{Vec3f}(undef, width * height)
    fill!(normal, Vec3f(0, 0, 0))
    hits = Vector{Int}(undef, width * height)
    fill!(hits, 0)
    denoised = Vector{Vec4f}(undef, 0)
    if params.denoise
        denoised = Vector{Vec4f}(undef, width * height)
        fill!(denoised, Vec4f(0, 0, 0, 0))
    end
    TraceState(width, height, samples, image, albedo, normal, hits, denoised)
end

function trace_samples(state::TraceState, scene::SceneData, bvh::SceneBvh, lights, params)
    if state.samples >= params.samples
        return
    end
    if params.noparallel || true
        for j in 0:(state.height - 1)
            for i in 0:(state.width - 1)
                trace_sample(state, scene, bvh, lights, i, j, state.samples, params)
            end
        end
    else
        #todo
    end
    state.samples += 1
end

function trace_path(scene::SceneData, bvh::SceneBvh, lights, ray::Ray3f, params) end

function trace_naive(
    scene::SceneData,
    bvh::SceneBvh,
    lights,
    ray_::Ray3f,
    params,
)::Tuple{Vec3f,Bool,Vec3f,Vec3f}
    radiance = Vec3f(0, 0, 0)
    weight = Vec3f(1, 1, 1)
    ray = Ray3f(ray_)
    hit = false
    hit_albedo = Vec3f(0, 0, 0)
    hit_normal = Vec3f(0, 0, 0)
    opbounce = 0

    for bounce in 0:(params.bounces - 1)
        intersection = intersect_scene_bvh(bvh, scene, ray, false)
        if !intersection.hit
            if bounce > 0 || !params.envhidden
                radiance += weight .* eval_environment(scene, ray.d)
            end
            break
        end

        outgoing = -ray.d
        position = eval_shading_position(
            scene,
            scene.instances[intersection.instance],
            intersection.element,
            intersection.uv,
            outgoing,
        )
        normal = eval_shading_normal(
            scene,
            scene.instances[intersection.instance],
            intersection.element,
            intersection.uv,
            outgoing,
        )
        material = eval_material(
            scene,
            scene.instances[intersection.instance],
            intersection.element,
            intersection.uv,
        )

        if (material.opacity < 1 && rand1f() >= material.opacity)
            if opbounce > 128
                break
            end
            opbounce += 1
            ray = (position + ray.d * 1e-2, ray.d)
            bounce -= 1
            continue
        end

        if bounce == 0
            hit = true
            #todo albedo is different
            hit_albedo = material.color
            hit_normal = normal
        end

        radiance += weight .* eval_emission(material, normal, outgoing)

        incoming = Vec3f(0, 0, 0)
        #         if (material.roughness != 0)
        #             incoming = sample_bsdfcos(material, normal, outgoing, rand1f(), rand2f())
        #             if (incoming == Vec3f(0, 0, 0))
        #                 break
        #             end
        #             weight *=
        #                 eval_bsdfcos(material, normal, outgoing, incoming) /
        #                 sample_bsdfcos_pdf(material, normal, outgoing, incoming)
        #         else
        #             incoming = sample_delta(material, normal, outgoing, rand1f())
        #             if (incoming == Vec3f(0, 0, 0))
        #                 break
        #             end
        #             weight *=
        #                 eval_delta(material, normal, outgoing, incoming) /
        #                 sample_delta_pdf(material, normal, outgoing, incoming)
        #         end

        if (weight == Vec3f(0, 0, 0) || !all(isfinite.(weight)))
            break
        end

        if (bounce > 3)
            rr_prob = min(0.99f0, maximum(weight))
            if (rand1f() >= rr_prob)
                break
            end
            weight *= 1 / rr_prob
        end

        ray = Ray3f(position, incoming)
    end
    @printf("ray_: %f %f %f\n", ray_.d[1], ray_.d[2], ray_.d[3])
    @printf("radiance: %f %f %f\n", radiance[1], radiance[2], radiance[3])
    @printf("albedo: %f %f %f\n", hit_albedo[1], hit_albedo[2], hit_albedo[3])
    @printf("normal: %f %f %f\n", hit_normal[1], hit_normal[2], hit_normal[3])
    @printf("hit: %d\n", hit)
    @printf("weight: %f %f %f\n", weight[1], weight[2], weight[3])

    return (radiance, hit, hit_albedo, hit_normal)
end

eval_emission(material::MaterialPoint, normal::Vec3f, outgoing::Vec3f) =
    if dot(normal, outgoing) >= 0
        material.emission
    else
        Vec3f(0, 0, 0)
    end

const SAMPLERS = [trace_path, trace_naive]

function trace_sample(
    state::TraceState,
    scene::SceneData,
    bvh::SceneBvh,
    lights,
    i,
    j,
    sample::Int,
    params,
)
    camera = scene.cameras[params.camera]
    idx = state.width * j + i + 1
    ray = sample_camera(
        camera,
        Vec2i(i, j),
        Vec2i(state.width, state.height),
        Vec2f(0, 0),
        Vec2f(0, 0),
        params.tentfilter,
    )
    radiance, hit, albedo, normal =
        SAMPLERS[params.sampler](scene, bvh, lights, ray, params)
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
        state.image[idx] =
            lerp(state.image[idx], Vec4f(radiance.x, radiance.y, radiance.z, 1), weight)
        state.albedo[idx] = lerp(state.albedo[idx], Vec3f(1, 1, 1), weight)
        state.normal[idx] = lerp(state.normal[idx], -ray.d, weight)
        state.hits[idx] += 1
    else
        state.image[idx] = lerp(state.image[idx], Vec4f(0, 0, 0, 0), weight)
        state.albedo[idx] = lerp(state.albedo[idx], Vec3f(0, 0, 0), weight)
        state.normal[idx] = lerp(state.normal[idx], -ray.d, weight)
    end
    @printf(
        "image: %f %f %f %f\n",
        state.image[idx][1],
        state.image[idx][2],
        state.image[idx][3],
        state.image[idx][4],
    )
    @printf(
        "albedo: %f %f %f\n",
        state.albedo[idx][1],
        state.albedo[idx][2],
        state.albedo[idx][3]
    )
    @printf(
        "normal: %f %f %f\n",
        state.normal[idx][1],
        state.normal[idx][2],
        state.normal[idx][3]
    )
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

end
