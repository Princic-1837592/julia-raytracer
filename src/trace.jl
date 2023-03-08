#=
trace:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-02-26
=#

module Trace

using DataStructures: Stack, first
using ..Scene:
    SceneData,
    CameraData,
    eval_camera,
    eval_shading_position,
    eval_shading_normal,
    eval_material,
    eval_environment,
    is_delta,
    MaterialPoint,
    matte,
    glossy,
    reflective,
    transparent,
    refractive,
    subsurface,
    volumetric,
    gltfpbr
using ..Shading:
    sample_matte,
    eval_matte,
    sample_matte_pdf,
    sample_reflective,
    eval_reflective,
    sample_reflective_pdf,
    sample_glossy,
    eval_glossy,
    sample_glossy_pdf
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
    if params.noparallel
        for j in 0:(state.height - 1)
            for i in 0:(state.width - 1)
                trace_sample(state, scene, bvh, lights, i, j, state.samples, params)
            end
        end
    else
        Threads.@threads for j in 0:(state.height - 1)
            Threads.@threads for i in 0:(state.width - 1)
                trace_sample(state, scene, bvh, lights, i, j, state.samples, params)
            end
        end
    end
    state.samples += 1
end

function trace_path(scene::SceneData, bvh::SceneBvh, lights, ray_::Ray3f, params)
    # initialize
    radiance = Vec3f(0, 0, 0)
    weight = Vec3f(1, 1, 1)
    ray = ray_
    volume_stack = Stack{MaterialPoint}()
    max_roughness = 0.0f0
    hit = false
    hit_albedo = Vec3f(0, 0, 0)
    hit_normal = Vec3f(0, 0, 0)
    opbounce = 0

    # trace  path
    for bounce in 0:(params.bounces - 1)
        # intersect next point
        intersection = intersect_scene_bvh(bvh, scene, ray, false)
        if (!intersection.hit)
            if (bounce > 0 || !params.envhidden)
                radiance += weight * eval_environment(scene, ray.d)
            end
            break
        end

        # handle transmission if inside a volume
        in_volume = false
        if (length(volume_stack) != 0)
            vsdf = first(volume_stack)
            distance = sample_transmittance(
                vsdf.density,
                intersection.distance,
                rand1f(),
                rand1f(),
            )
            weight *=
                eval_transmittance(vsdf.density, distance) /
                sample_transmittance_pdf(vsdf.density, distance, intersection.distance)
            in_volume = distance < intersection.distance
            intersection.distance = distance
        end

        # switch between surface and volume
        if (!in_volume)
            # prepare shading point
            outgoing = -ray.d
            position = eval_shading_position(
                scene,
                scene.instances[intersection.instance],
                intersection.element,
                intersection.uv,
                outgoing,
            )
            #confirmed correct
            normal = eval_shading_normal(
                scene,
                scene.instances[intersection.instance],
                intersection.element,
                intersection.uv,
                outgoing,
            )
            #confirmed correct
            material = eval_material(
                scene,
                scene.instances[intersection.instance],
                intersection.element,
                intersection.uv,
            )

            # correct roughness
            if (params.nocaustics)
                max_roughness = max(material.roughness, max_roughness)
                material.roughness = max_roughness
            end

            # handle opacity
            if (material.opacity < 1 && rand1f() >= material.opacity)
                if (opbounce > 128)
                    break
                end
                opbounce += 1
                ray = Ray3f(position + ray.d * 1e-2, ray.d)
                bounce -= 1
                continue
            end

            # set hit variables
            if (bounce == 0)
                hit = true
                hit_albedo = material.color
                hit_normal = normal
            end

            # accumulate emission
            radiance += weight .* eval_emission(material, normal, outgoing)

            # next direction
            incoming = Vec3f(0, 0, 0)
            if (!is_delta(material))
                if (rand1f() < 0.5f0)
                    incoming =
                        sample_bsdfcos(material, normal, outgoing, rand1f(), rand2f())
                else
                    incoming =
                        sample_lights(scene, lights, position, rand1f(), rand1f(), rand2f())
                end
                if (incoming == Vec3f(0, 0, 0))
                    break
                end
                weight *=
                    eval_bsdfcos(material, normal, outgoing, incoming) / (
                        0.5f0 * sample_bsdfcos_pdf(material, normal, outgoing, incoming) +
                        0.5f0 * sample_lights_pdf(scene, bvh, lights, position, incoming)
                    )
            else
                incoming = sample_delta(material, normal, outgoing, rand1f())
                weight *=
                    eval_delta(material, normal, outgoing, incoming) /
                    sample_delta_pdf(material, normal, outgoing, incoming)
            end

            # update volume stack
            if (
                is_volumetric(scene, intersection) &&
                dot(normal, outgoing) * dot(normal, incoming) < 0
            )
                if (length(volume_stack) == 0)
                    material = eval_material(scene, intersection)
                    push!(volume_stack, material)
                else
                    pop!(volume_stack)
                end
            end

            # setup next iteration
            ray = Ray3f(position, incoming)
        else
            # prepare shading point
            outgoing = -ray.d
            position = ray.o + ray.d * intersection.distance
            vsdf = first(volume_stack)

            # accumulate emission
            # radiance += weight * eval_volemission(emission, outgoing)

            # next direction
            incoming = Vec3f(0, 0, 0)
            if (rand1f() < 0.5f0)
                incoming = sample_scattering(vsdf, outgoing, rand1f(), rand2f())
            else
                incoming =
                    sample_lights(scene, lights, position, rand1f(), rand1f(), rand2f())
            end
            if (incoming == Vec3f(0, 0, 0))
                break
            end
            weight *=
                eval_scattering(vsdf, outgoing, incoming) / (
                    0.5f0 * sample_scattering_pdf(vsdf, outgoing, incoming) +
                    0.5f0 * sample_lights_pdf(scene, bvh, lights, position, incoming)
                )

            # setup next iteration
            ray = Ray3f(position, incoming)
        end

        # check weight
        if (weight == Vec3f(0, 0, 0) || !all(isfinite.(weight)))
            break
        end

        # russian roulette
        if (bounce > 3)
            rr_prob = min(0.99f0, maximum(weight))
            if (rand1f() >= rr_prob)
                break
            end
            weight *= 1 / rr_prob
        end
    end

    return (radiance, hit, hit_albedo, hit_normal)
end

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
        #         @printf("radiance: %.5f %.5f %.5f ", radiance[1], radiance[2], radiance[3])

        outgoing = -ray.d
        #confirmed correct
        position = eval_shading_position(
            scene,
            scene.instances[intersection.instance],
            intersection.element,
            intersection.uv,
            outgoing,
        )
        #confirmed correct
        normal = eval_shading_normal(
            scene,
            scene.instances[intersection.instance],
            intersection.element,
            intersection.uv,
            outgoing,
        )
        #confirmed correct
        material = eval_material(
            scene,
            scene.instances[intersection.instance],
            intersection.element,
            intersection.uv,
        )
        #         @printf("position: %.5f %.5f %.5f ", position[1], position[2], position[3])
        #         @printf("normal: %.5f %.5f %.5f\n", normal[1], normal[2], normal[3])
        #         @printf("%s\n", material.type)
        #         @printf(
        #             "emission: %.5f %.5f %.5f ",
        #             material.emission[1],
        #             material.emission[2],
        #             material.emission[3]
        #         )
        #         @printf(
        #             "color: %.5f %.5f %.5f\n",
        #             material.color[1],
        #             material.color[2],
        #             material.color[3]
        #         )
        #         @printf("opacity: %.5f ", material.opacity)
        #         @printf("roughness: %.5f ", material.roughness)
        #         @printf("metallic: %.5f ", material.metallic)
        #         @printf("ior: %.5f ", material.ior)
        #         @printf("scanisotropy: %.5f ", material.scanisotropy)
        #         @printf("trdepth: %.5f\n", material.trdepth)
        #         @printf(
        #             "density: %.5f %.5f %.5f ",
        #             material.density[1],
        #             material.density[2],
        #             material.density[3]
        #         )
        #         @printf(
        #             "scattering: %.5f %.5f %.5f\n",
        #             material.scattering[1],
        #             material.scattering[2],
        #             material.scattering[3]
        #         )

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
            hit_albedo = material.color
            hit_normal = normal
        end

        radiance += weight .* eval_emission(material, normal, outgoing)

        incoming = Vec3f(0, 0, 0)
        if (material.roughness != 0)
            incoming = sample_bsdfcos(material, normal, outgoing, rand1f(), rand2f())
            if (incoming == Vec3f(0, 0, 0))
                break
            end
            weight =
                weight .* eval_bsdfcos(material, normal, outgoing, incoming) /
                sample_bsdfcos_pdf(material, normal, outgoing, incoming)
        else
            incoming = sample_delta(material, normal, outgoing, rand1f())
            if (incoming == Vec3f(0, 0, 0))
                break
            end
            weight =
                weight .* eval_delta(material, normal, outgoing, incoming) /
                sample_delta_pdf(material, normal, outgoing, incoming)
        end

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
        #         @printf("radiance: %.5f %.5f %.5f\n", radiance[1], radiance[2], radiance[3])
    end
    #     @printf("\n")
    #     @printf("radiance: %.5f %.5f %.5f\n", radiance[1], radiance[2], radiance[3])
    #     @printf("albedo: %.5f %.5f %.5f ", hit_albedo[1], hit_albedo[2], hit_albedo[3])
    #     @printf("normal: %.5f %.5f %.5f\n", hit_normal[1], hit_normal[2], hit_normal[3])
    #     @printf("hit: %d ", hit)
    #     @printf("weight: %.5f %.5f %.5f\n", weight[1], weight[2], weight[3])

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
    if i == 33 && j == 8
        #         @printf("next rand: %.5f\n", rand1f())
    end
    puv = rand2f()
    luv = rand2f()
    #     @printf("ij: %d %d ", i, j)
    #     @printf("puv: %.5f %.5f ", puv[1], puv[2])
    #     @printf("luv: %.5f %.5f\n", luv[1], luv[2])
    ray = sample_camera(
        camera,
        Vec2i(i, j),
        Vec2i(state.width, state.height),
        puv,
        luv,
        params.tentfilter,
    )
    if i == 33 && j == 8
        #         @printf("next rand: %.5f\n", rand1f())
    end
    #     ray = sample_camera(
    #         camera,
    #         Vec2i(i, j),
    #         Vec2i(state.width, state.height),
    #         Vec2f(),
    #         Vec2f(),
    #         params.tentfilter,
    #     )
    #     @printf("ray.d: %d %d %.5f %.5f %.5f\n", i, j, ray.d[1], ray.d[2], ray.d[3])
    #confirmed correct hit, albedo, normal
    radiance, hit, albedo, normal =
        SAMPLERS[params.sampler](scene, bvh, lights, ray, params)
    #             @printf("radiance: %.5f %.5f %.5f ", radiance[1], radiance[2], radiance[3])
    if !all(isfinite.(radiance))
        radiance = Vec3f(0, 0, 0)
    end
    #todo
    if (maximum(radiance) > params.clamp)
        radiance = radiance .* (params.clamp / maximum(radiance))
    end
    weight = 1.0f0 / (sample + 1)
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
    #     @printf(
    #         "image: %.5f %.5f %.5f %.5f ",
    #         state.image[idx][1],
    #         state.image[idx][2],
    #         state.image[idx][3],
    #         state.image[idx][4],
    #     )
    #     @printf(
    #         "albedo: %.5f %.5f %.5f ",
    #         state.albedo[idx][1],
    #         state.albedo[idx][2],
    #         state.albedo[idx][3]
    #     )
    #     @printf(
    #         "normal: %.5f %.5f %.5f\n",
    #         state.normal[idx][1],
    #         state.normal[idx][2],
    #         state.normal[idx][3]
    #     )
end

#confirmed correct
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
        sd = sample_disk(luv)
        #         @printf("uv %.5f %.5f sd %.5f %.5f\n", uv[1], uv[2], sd[1], sd[2])
        eval_camera(camera, uv, sd)
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
        image.pixels = state.image
    else
        image.pixels = state.denoised
    end
    for pixel in image.pixels
        #         @printf("pixel: %.5f %.5f %.5f %.5f\n", pixel[1], pixel[2], pixel[3], pixel[4])
    end
end

function eval_bsdfcos(
    material::MaterialPoint,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Vec3f
    if material.roughness == 0
        return Vec3f(0, 0, 0)
    end

    if material.type == matte
        eval_matte(material.color, normal, outgoing, incoming)
    elseif material.type == glossy
        eval_glossy(
            material.color,
            material.ior,
            material.roughness,
            normal,
            outgoing,
            incoming,
        )
    elseif material.type == reflective
        eval_reflective(material.color, material.roughness, normal, outgoing, incoming)
    elseif material.type == transparent
        eval_transparent(
            material.color,
            material.ior,
            material.roughness,
            normal,
            outgoing,
            incoming,
        )
    elseif material.type == refractive
        eval_refractive(
            material.color,
            material.ior,
            material.roughness,
            normal,
            outgoing,
            incoming,
        )
    elseif material.type == subsurface
        eval_refractive(
            material.color,
            material.ior,
            material.roughness,
            normal,
            outgoing,
            incoming,
        )
    elseif material.type == gltfpbr
        eval_gltfpbr(
            material.color,
            material.ior,
            material.roughness,
            material.metallic,
            normal,
            outgoing,
            incoming,
        )
    else
        Vec3f(0, 0, 0)
    end
end

function eval_delta(
    material::MaterialPoint,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Vec3f
    if (material.roughness != 0)
        return Vec3f(0, 0, 0)
    end

    if material.type == reflective
        eval_reflective(material.color, normal, outgoing, incoming)
    elseif material.type == transparent
        eval_transparent(material.color, material.ior, normal, outgoing, incoming)
    elseif material.type == refractive
        eval_refractive(material.color, material.ior, normal, outgoing, incoming)
    elseif material.type == volumetric
        eval_passthrough(material.color, normal, outgoing, incoming)
    else
        Vec3f(0, 0, 0)
    end
end

function sample_bsdfcos(
    material::MaterialPoint,
    normal::Vec3f,
    outgoing::Vec3f,
    rnl::Float32,
    rn::Vec2f,
)::Vec3f
    if (material.roughness == 0)
        return Vec3f(0, 0, 0)
    end

    if material.type == matte
        sample_matte(material.color, normal, outgoing, rn)
    elseif material.type == glossy
        sample_glossy(
            material.color,
            material.ior,
            material.roughness,
            normal,
            outgoing,
            rnl,
            rn,
        )
    elseif material.type == reflective
        sample_reflective(material.color, material.roughness, normal, outgoing, rn)
    elseif material.type == transparent
        sample_transparent(
            material.color,
            material.ior,
            material.roughness,
            normal,
            outgoing,
            rnl,
            rn,
        )
    elseif material.type == refractive
        sample_refractive(
            material.color,
            material.ior,
            material.roughness,
            normal,
            outgoing,
            rnl,
            rn,
        )
    elseif material.type == subsurface
        sample_refractive(
            material.color,
            material.ior,
            material.roughness,
            normal,
            outgoing,
            rnl,
            rn,
        )
    elseif material.type == gltfpbr
        sample_gltfpbr(
            material.color,
            material.ior,
            material.roughness,
            material.metallic,
            normal,
            outgoing,
            rnl,
            rn,
        )
    else
        Vec3f(0, 0, 0)
    end
end

function sample_delta(
    material::MaterialPoint,
    normal::Vec3f,
    outgoing::Vec3f,
    rnl::Float32,
)::Vec3f
    if material.roughness != 0
        return Vec3f(0, 0, 0)
    end

    if material.type == reflective
        sample_reflective(material.color, normal, outgoing)
    elseif material.type == transparent
        sample_transparent(material.color, material.ior, normal, outgoing, rnl)
    elseif material.type == refractive
        sample_refractive(material.color, material.ior, normal, outgoing, rnl)
    elseif material.type == volumetric
        sample_passthrough(material.color, normal, outgoing)
    else
        Vec3f(0, 0, 0)
    end
end

function sample_bsdfcos_pdf(
    material::MaterialPoint,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Float32
    if material.roughness == 0
        return 0
    end

    if material.type == matte
        sample_matte_pdf(material.color, normal, outgoing, incoming)
    elseif material.type == glossy
        sample_glossy_pdf(
            material.color,
            material.ior,
            material.roughness,
            normal,
            outgoing,
            incoming,
        )
    elseif material.type == reflective
        sample_reflective_pdf(
            material.color,
            material.roughness,
            normal,
            outgoing,
            incoming,
        )
    elseif material.type == transparent
        sample_transparent_pdf(
            material.color,
            material.ior,
            material.roughness,
            normal,
            outgoing,
            incoming,
        )
    elseif material.type == refractive
        sample_refractive_pdf(
            material.color,
            material.ior,
            material.roughness,
            normal,
            outgoing,
            incoming,
        )
    elseif material.type == subsurface
        sample_refractive_pdf(
            material.color,
            material.ior,
            material.roughness,
            normal,
            outgoing,
            incoming,
        )
    elseif material.type == gltfpbr
        sample_gltfpbr_pdf(
            material.color,
            material.ior,
            material.roughness,
            material.metallic,
            normal,
            outgoing,
            incoming,
        )
    else
        0
    end
end

function sample_delta_pdf(
    material::MaterialPoint,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Float32
    if material.roughness != 0
        return 0
    end

    if material.type == reflective
        sample_reflective_pdf(material.color, normal, outgoing, incoming)
    elseif material.type == transparent
        sample_transparent_pdf(material.color, material.ior, normal, outgoing, incoming)
    elseif material.type == refractive
        sample_refractive_pdf(material.color, material.ior, normal, outgoing, incoming)
    elseif material.type == volumetric
        sample_passthrough_pdf(material.color, normal, outgoing, incoming)
    else
        0
    end
end

end
