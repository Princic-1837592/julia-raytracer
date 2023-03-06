#=
shading:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-03-06
=#

module Shading

using ..Math: Vec3f, Vec2f, pif, dot, Mat3f, normalize, transform_direction
using ..Sampling: sample_hemisphere_cos_pdf

function eval_matte(color::Vec3f, normal::Vec3f, outgoing::Vec3f, incoming::Vec3f)::Vec3f
    if (dot(normal, incoming) * dot(normal, outgoing) <= 0)
        return Vec3f(0, 0, 0)
    end
    color / pif * abs(dot(normal, incoming))
end

function sample_matte(color::Vec3f, normal::Vec3f, outgoing::Vec3f, rn::Vec2f)::Vec3f
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    sample_hemisphere_cos(up_normal, rn)
end

function sample_matte_pdf(
    color::Vec3f,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Float32
    if (dot(normal, incoming) * dot(normal, outgoing) <= 0)
        return 0
    end
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    sample_hemisphere_cos_pdf(up_normal, incoming)
end

function eval_glossy(
    color::Vec3f,
    ior::Float32,
    roughness::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Vec3f
    if (dot(normal, incoming) * dot(normal, outgoing) <= 0)
        return Vec3f(0, 0, 0)
    end
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    F1 = fresnel_dielectric(ior, up_normal, outgoing)
    halfway = normalize(incoming + outgoing)
    F = fresnel_dielectric(ior, halfway, incoming)
    D = microfacet_distribution(roughness, up_normal, halfway)
    G = microfacet_shadowing(roughness, up_normal, halfway, outgoing, incoming)
    color * (1 - F1) / pif * abs(dot(up_normal, incoming)) +
    Vec3f(1, 1, 1) * F * D * G / (4 * dot(up_normal, outgoing) * dot(up_normal, incoming)) *
    abs(dot(up_normal, incoming))
end

function sample_glossy(
    color::Vec3f,
    ior::Float32,
    roughness::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    rnl::Float32,
    rn::Vec2f,
)::Vec3f
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    if (rnl < fresnel_dielectric(ior, up_normal, outgoing))
        halfway = sample_microfacet(roughness, up_normal, rn)
        incoming = reflect(outgoing, halfway)
        if (!same_hemisphere(up_normal, outgoing, incoming))
            return Vec3f(0, 0, 0)
        end
        incoming
    else
        sample_hemisphere_cos(up_normal, rn)
    end
end

function sample_glossy_pdf(
    color::Vec3f,
    ior::Float32,
    roughness::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Float32
    if (dot(normal, incoming) * dot(normal, outgoing) <= 0)
        return 0
    end
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    halfway = normalize(outgoing + incoming)
    F = fresnel_dielectric(ior, up_normal, outgoing)
    F * sample_microfacet_pdf(roughness, up_normal, halfway) /
    (4 * abs(dot(outgoing, halfway))) +
    (1 - F) * sample_hemisphere_cos_pdf(up_normal, incoming)
end

function eval_reflective(
    color::Vec3f,
    roughness::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Vec3f
    if (dot(normal, incoming) * dot(normal, outgoing) <= 0)
        return Vec3f(0, 0, 0)
    end
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    halfway = normalize(incoming + outgoing)
    F = fresnel_conductor(reflectivity_to_eta(color), Vec3f(0, 0, 0), halfway, incoming)
    D = microfacet_distribution(roughness, up_normal, halfway)
    G = microfacet_shadowing(roughness, up_normal, halfway, outgoing, incoming)
    F * D * G / (4 * dot(up_normal, outgoing) * dot(up_normal, incoming)) *
    abs(dot(up_normal, incoming))
end

function sample_reflective(
    color::Vec3f,
    roughness::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    rn::Vec2f,
)::Vec3f
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    halfway = sample_microfacet(roughness, up_normal, rn)
    incoming = reflect(outgoing, halfway)
    if (!same_hemisphere(up_normal, outgoing, incoming))
        return Vec3f(0, 0, 0)
    end
    incoming
end

function sample_reflective_pdf(
    color::Vec3f,
    roughness::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Float32
    if (dot(normal, incoming) * dot(normal, outgoing) <= 0)
        return 0
    end
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    halfway = normalize(outgoing + incoming)
    sample_microfacet_pdf(roughness, up_normal, halfway) / (4 * abs(dot(outgoing, halfway)))
end

function eval_reflective(
    eta::Vec3f,
    etak::Vec3f,
    roughness::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Vec3f
    if (dot(normal, incoming) * dot(normal, outgoing) <= 0)
        return Vec3f(0, 0, 0)
    end
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    halfway = normalize(incoming + outgoing)
    F = fresnel_conductor(eta, etak, halfway, incoming)
    D = microfacet_distribution(roughness, up_normal, halfway)
    G = microfacet_shadowing(roughness, up_normal, halfway, outgoing, incoming)
    F * D * G / (4 * dot(up_normal, outgoing) * dot(up_normal, incoming)) *
    abs(dot(up_normal, incoming))
end

function sample_reflective(
    eta::Vec3f,
    etak::Vec3f,
    roughness::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    rn::Vec2f,
)::Vec3f
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    halfway = sample_microfacet(roughness, up_normal, rn)
    reflect(outgoing, halfway)
end

function sample_reflective_pdf(
    eta::Vec3f,
    etak::Vec3f,
    roughness::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Float32
    if (dot(normal, incoming) * dot(normal, outgoing) <= 0)
        return 0
    end
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    halfway = normalize(outgoing + incoming)
    sample_microfacet_pdf(roughness, up_normal, halfway) / (4 * abs(dot(outgoing, halfway)))
end

function eval_reflective(
    color::Vec3f,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Vec3f
    if (dot(normal, incoming) * dot(normal, outgoing) <= 0)
        return Vec3f(0, 0, 0)
    end
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    fresnel_conductor(reflectivity_to_eta(color), Vec3f(0, 0, 0), up_normal, outgoing)
end

function sample_reflective(color::Vec3f, normal::Vec3f, outgoing::Vec3f)::Vec3f
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    reflect(outgoing, up_normal)
end

function sample_reflective_pdf(
    color::Vec3f,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Float32
    if (dot(normal, incoming) * dot(normal, outgoing) <= 0)
        return 0
    end
    1
end

function eval_reflective(
    eta::Vec3f,
    etak::Vec3f,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Vec3f
    if (dot(normal, incoming) * dot(normal, outgoing) <= 0)
        return Vec3f(0, 0, 0)
    end
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    fresnel_conductor(eta, etak, up_normal, outgoing)
end

function sample_reflective(eta::Vec3f, etak::Vec3f, normal::Vec3f, outgoing::Vec3f)::Vec3f
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    reflect(outgoing, up_normal)
end

function sample_reflective_pdf(
    eta::Vec3f,
    etak::Vec3f,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Float32
    if (dot(normal, incoming) * dot(normal, outgoing) <= 0)
        return 0
    end
    1
end

function eval_gltfpbr(
    color::Vec3f,
    ior::Float32,
    roughness::Float32,
    metallic::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Vec3f
    if (dot(normal, incoming) * dot(normal, outgoing) <= 0)
        return Vec3f(0, 0, 0)
    end
    reflectivity = lerp(eta_to_reflectivity(Vec3f(ior, ior, ior)), color, metallic)
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    F1 = fresnel_schlick(reflectivity, up_normal, outgoing)
    halfway = normalize(incoming + outgoing)
    F = fresnel_schlick(reflectivity, halfway, incoming)
    D = microfacet_distribution(roughness, up_normal, halfway)
    G = microfacet_shadowing(roughness, up_normal, halfway, outgoing, incoming)
    color * (1 - metallic) * (1 - F1) / pif * abs(dot(up_normal, incoming)) +
    F * D * G / (4 * dot(up_normal, outgoing) * dot(up_normal, incoming)) *
    abs(dot(up_normal, incoming))
end

function sample_gltfpbr(
    color::Vec3f,
    ior::Float32,
    roughness::Float32,
    metallic::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    rnl::Float32,
    rn::Vec2f,
)::Vec3f
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    reflectivity = lerp(eta_to_reflectivity(Vec3f(ior, ior, ior)), color, metallic)
    if (rnl < mean(fresnel_schlick(reflectivity, up_normal, outgoing)))
        halfway = sample_microfacet(roughness, up_normal, rn)
        incoming = reflect(outgoing, halfway)
        if (!same_hemisphere(up_normal, outgoing, incoming))
            return Vec3f(0, 0, 0)
        end
        incoming
    else
        sample_hemisphere_cos(up_normal, rn)
    end
end

function sample_gltfpbr_pdf(
    color::Vec3f,
    ior::Float32,
    roughness::Float32,
    metallic::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Float32
    if (dot(normal, incoming) * dot(normal, outgoing) <= 0)
        return 0
    end
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    halfway = normalize(outgoing + incoming)
    reflectivity = lerp(eta_to_reflectivity(Vec3f(ior, ior, ior)), color, metallic)
    F = mean(fresnel_schlick(reflectivity, up_normal, outgoing))
    F * sample_microfacet_pdf(roughness, up_normal, halfway) /
    (4 * abs(dot(outgoing, halfway))) +
    (1 - F) * sample_hemisphere_cos_pdf(up_normal, incoming)
end

function eval_transparent(
    color::Vec3f,
    ior::Float32,
    roughness::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Vec3f
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    if (dot(normal, incoming) * dot(normal, outgoing) >= 0)
        halfway = normalize(incoming + outgoing)
        F = fresnel_dielectric(ior, halfway, outgoing)
        D = microfacet_distribution(roughness, up_normal, halfway)
        G = microfacet_shadowing(roughness, up_normal, halfway, outgoing, incoming)
        Vec3f(1, 1, 1) * F * D * G /
        (4 * dot(up_normal, outgoing) * dot(up_normal, incoming)) *
        abs(dot(up_normal, incoming))
    else
        reflected = reflect(-incoming, up_normal)
        halfway = normalize(reflected + outgoing)
        F = fresnel_dielectric(ior, halfway, outgoing)
        D = microfacet_distribution(roughness, up_normal, halfway)
        G = microfacet_shadowing(roughness, up_normal, halfway, outgoing, reflected)
        color * (1 - F) * D * G /
        (4 * dot(up_normal, outgoing) * dot(up_normal, reflected)) *
        (abs(dot(up_normal, reflected)))
    end
end

function sample_transparent(
    color::Vec3f,
    ior::Float32,
    roughness::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    rnl::Float32,
    rn::Vec2f,
)::Vec3f
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    halfway = sample_microfacet(roughness, up_normal, rn)
    if (rnl < fresnel_dielectric(ior, halfway, outgoing))
        incoming = reflect(outgoing, halfway)
        if (!same_hemisphere(up_normal, outgoing, incoming))
            return Vec3f(0, 0, 0)
        end
        incoming
    else
        reflected = reflect(outgoing, halfway)
        incoming = -reflect(reflected, up_normal)
        if (same_hemisphere(up_normal, outgoing, incoming))
            return Vec3f(0, 0, 0)
        end
        incoming
    end
end

function sample_tranparent_pdf(
    color::Vec3f,
    ior::Float32,
    roughness::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Float32end
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    if (dot(normal, incoming) * dot(normal, outgoing) >= 0)
        halfway = normalize(incoming + outgoing)
        fresnel_dielectric(ior, halfway, outgoing) *
        sample_microfacet_pdf(roughness, up_normal, halfway) /
        (4 * abs(dot(outgoing, halfway)))
    else
        reflected = reflect(-incoming, up_normal)
        halfway = normalize(reflected + outgoing)
        d =
            (1 - fresnel_dielectric(ior, halfway, outgoing)) *
            sample_microfacet_pdf(roughness, up_normal, halfway)
        d / (4 * abs(dot(outgoing, halfway)))
    end
end

function eval_transparent(
    color::Vec3f,
    ior::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Vec3f
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    if (dot(normal, incoming) * dot(normal, outgoing) >= 0)
        Vec3f(1, 1, 1) * fresnel_dielectric(ior, up_normal, outgoing)
    else
        color * (1 - fresnel_dielectric(ior, up_normal, outgoing))
    end
end

function sample_transparent(
    color::Vec3f,
    ior::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    rnl::Float32,
)::Vec3f
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    if (rnl < fresnel_dielectric(ior, up_normal, outgoing))
        reflect(outgoing, up_normal)
    else
        -outgoing
    end
end

function sample_tranparent_pdf(
    color::Vec3f,
    ior::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Float32
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    if (dot(normal, incoming) * dot(normal, outgoing) >= 0)
        fresnel_dielectric(ior, up_normal, outgoing)
    else
        1 - fresnel_dielectric(ior, up_normal, outgoing)
    end
end

function eval_refractive(
    color::Vec3f,
    ior::Float32,
    roughness::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Vec3f
    entering = dot(normal, outgoing) >= 0
    up_normal = entering ? normal : -normal
    rel_ior = entering ? ior : (1 / ior)
    if (dot(normal, incoming) * dot(normal, outgoing) >= 0)
        halfway = normalize(incoming + outgoing)
        F = fresnel_dielectric(rel_ior, halfway, outgoing)
        D = microfacet_distribution(roughness, up_normal, halfway)
        G = microfacet_shadowing(roughness, up_normal, halfway, outgoing, incoming)
        Vec3f(1, 1, 1) * F * D * G /
        abs(4 * dot(normal, outgoing) * dot(normal, incoming)) * abs(dot(normal, incoming))
    else
        halfway = -normalize(rel_ior * incoming + outgoing) * (entering ? 1.0f : -1.0f)
        F = fresnel_dielectric(rel_ior, halfway, outgoing)
        D = microfacet_distribution(roughness, up_normal, halfway)
        G = microfacet_shadowing(roughness, up_normal, halfway, outgoing, incoming)
        # [Walter 2007] equation 21
        Vec3f(1, 1, 1) *
        abs(
            (dot(outgoing, halfway) * dot(incoming, halfway)) /
            (dot(outgoing, normal) * dot(incoming, normal)),
        ) *
        (1 - F) *
        D *
        G / pow(rel_ior * dot(halfway, incoming) + dot(halfway, outgoing), 2.0f) *
        abs(dot(normal, incoming))
    end
end

function sample_refractive(
    color::Vec3f,
    ior::Float32,
    roughness::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    rnl::Float32,
    rn::Vec2f,
)::Vec3f
    entering = dot(normal, outgoing) >= 0
    up_normal = entering ? normal : -normal
    halfway = sample_microfacet(roughness, up_normal, rn)
    # halfway = sample_microfacet(roughness, up_normal, outgoing, rn)
    if (rnl < fresnel_dielectric(entering ? ior : (1 / ior), halfway, outgoing))
        incoming = reflect(outgoing, halfway)
        if (!same_hemisphere(up_normal, outgoing, incoming))
            return Vec3f(0, 0, 0)
        end
        incoming
    else
        incoming = refract(outgoing, halfway, entering ? (1 / ior) : ior)
        if (same_hemisphere(up_normal, outgoing, incoming))
            return Vec3f(0, 0, 0)
        end
        incoming
    end
end

function sample_refractive_pdf(
    color::Vec3f,
    ior::Float32,
    roughness::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Float32
    entering = dot(normal, outgoing) >= 0
    up_normal = entering ? normal : -normal
    rel_ior = entering ? ior : (1 / ior)
    if (dot(normal, incoming) * dot(normal, outgoing) >= 0)
        halfway = normalize(incoming + outgoing)
        fresnel_dielectric(rel_ior, halfway, outgoing) *
        sample_microfacet_pdf(roughness, up_normal, halfway) /
        #  sample_microfacet_pdf(roughness, up_normal, halfway, outgoing) /
        (4 * abs(dot(outgoing, halfway)))
    else
        halfway = -normalize(rel_ior * incoming + outgoing) * (entering ? 1.0f : -1.0f)
        # [Walter 2007] equation 17
        (1 - fresnel_dielectric(rel_ior, halfway, outgoing)) *
        sample_microfacet_pdf(roughness, up_normal, halfway) *
        #  sample_microfacet_pdf(roughness, up_normal, halfway, outgoing) /
        abs(dot(halfway, incoming)) /  # here we use incoming as from pbrt
        pow(rel_ior * dot(halfway, incoming) + dot(halfway, outgoing), 2.0f)
    end
end

function eval_refractive(
    color::Vec3f,
    ior::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Vec3f
    if (abs(ior - 1) < 1e-3)
        return if dot(normal, incoming) * dot(normal, outgoing) <= 0
            Vec3f(1, 1, 1)
        else
            Vec3f(0, 0, 0)
        end
    end
    entering = dot(normal, outgoing) >= 0
    up_normal = entering ? normal : -normal
    rel_ior = entering ? ior : (1 / ior)
    if (dot(normal, incoming) * dot(normal, outgoing) >= 0)
        Vec3f(1, 1, 1) * fresnel_dielectric(rel_ior, up_normal, outgoing)
    else
        Vec3f(1, 1, 1) *
        (1 / (rel_ior * rel_ior)) *
        (1 - fresnel_dielectric(rel_ior, up_normal, outgoing))
    end
end

function sample_refractive(
    color::Vec3f,
    ior::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    rnl::Float32,
)::Vec3f
    if (abs(ior - 1) < 1e-3)
        return -outgoing
    end
    entering = dot(normal, outgoing) >= 0
    up_normal = entering ? normal : -normal
    rel_ior = entering ? ior : (1 / ior)
    if (rnl < fresnel_dielectric(rel_ior, up_normal, outgoing))
        reflect(outgoing, up_normal)
    else
        refract(outgoing, up_normal, 1 / rel_ior)
    end
end

function sample_refractive_pdf(
    color::Vec3f,
    ior::Float32,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Float32
    if (abs(ior - 1) < 1e-3)
        return if dot(normal, incoming) * dot(normal, outgoing) < 0
            1.0f0
        else
            0.0f0
        end
    end
    entering = dot(normal, outgoing) >= 0
    up_normal = entering ? normal : -normal
    rel_ior = entering ? ior : (1 / ior)
    if (dot(normal, incoming) * dot(normal, outgoing) >= 0)
        fresnel_dielectric(rel_ior, up_normal, outgoing)
    else
        (1 - fresnel_dielectric(rel_ior, up_normal, outgoing))
    end
end

function eval_translucent(
    color::Vec3f,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Vec3f
    if (dot(normal, incoming) * dot(normal, outgoing) >= 0)
        return Vec3f(0, 0, 0)
    end
    color / pif * abs(dot(normal, incoming))
end

function sample_translucent(color::Vec3f, normal::Vec3f, outgoing::Vec3f, rn::Vec2f)::Vec3f
    up_normal = dot(normal, outgoing) <= 0 ? -normal : normal
    sample_hemisphere_cos(-up_normal, rn)
end

function sample_translucent_pdf(
    color::Vec3f,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Float32
    if (dot(normal, incoming) * dot(normal, outgoing) >= 0)
        return 0
    end
    up_normal = if dot(normal, outgoing) <= 0
        -normal
    else
        normal
    end
    sample_hemisphere_cos_pdf(-up_normal, incoming)
end

eval_passthrough(color::Vec3f, normal::Vec3f, outgoing::Vec3f, incoming::Vec3f)::Vec3f =
    if (dot(normal, incoming) * dot(normal, outgoing) >= 0)
        Vec3f(0, 0, 0)
    else
        Vec3f(1, 1, 1)
    end

sample_passthrough(color::Vec3f, normal::Vec3f, outgoing::Vec3f)::Vec3f = -outgoing

sample_passthrough_pdf(
    color::Vec3f,
    normal::Vec3f,
    outgoing::Vec3f,
    incoming::Vec3f,
)::Float32 =
    if (dot(normal, incoming) * dot(normal, outgoing) >= 0)
        return 0
    else
        return 1
    end

mfp_to_transmission(mfp::Vec3f, depth::Float32)::Vec3f = exp(-depth / mfp)

eval_transmittance(density::Vec3f, distance::Float32)::Vec3f = exp(-density * distance)

function sample_transmittance(
    density::Vec3f,
    max_distance::Float32,
    rl::Float32,
    rd::Float32,
)::Float32
    channel = clamp((int)(rl * 3), 0, 2)
    distance = if density[channel] == 0
        flt_max
    else
        -log(1 - rd) / density[channel]
    end
    return min(distance, max_distance)
end

sample_transmittance_pdf(
    density::Vec3f,
    distance::Float32,
    max_distance::Float32,
)::Float32 =
    if (distance < max_distance)
        sum(density * exp(-density * distance)) / 3
    else
        sum(exp(-density * max_distance)) / 3
    end

function eval_phasefunction(anisotropy::Float32, outgoing::Vec3f, incoming::Vec3f)::Float32
    cosine = -dot(outgoing, incoming)
    denom = 1 + anisotropy * anisotropy - 2 * anisotropy * cosine
    (1 - anisotropy * anisotropy) / (4 * pif * denom * sqrt(denom))
end

function sample_phasefunction(anisotropy::Float32, outgoing::Vec3f, rn::Vec2f)::Vec3f
    cos_theta = 0.0f0
    if (abs(anisotropy) < 1e-3f)
        cos_theta = 1 - 2 * rn.y
    else
        square = (1 - anisotropy * anisotropy) / (1 + anisotropy - 2 * anisotropy * rn.y)
        cos_theta = (1 + anisotropy * anisotropy - square * square) / (2 * anisotropy)
    end

    sin_theta = sqrt(max(0.0f, 1 - cos_theta * cos_theta))
    phi = 2 * pif * rn.x
    local_incoming = Vec3f
    sin_theta * cos(phi), sin_theta * sin(phi), cos_theta
    basis_fromz(-outgoing) * local_incoming
end

sample_phasefunction_pdf(anisotropy::Float32, outgoing::Vec3f, incoming::Vec3f)::Float32 =
    eval_phasefunction(anisotropy, outgoing, incoming)

function fresnel_dielectric(eta::Float32, normal::Vec3f, outgoing::Vec3f)::Float32
    # Implementation from
    # https://seblagarde.wordpress.com/2013/04/29/memo-on-fresnel-equations/
    cosw = abs(dot(normal, outgoing))

    sin2 = 1 - cosw * cosw
    eta2 = eta * eta

    cos2t = 1 - sin2 / eta2
    if (cos2t < 0)
        return 1
    end

    t0 = sqrt(cos2t)
    t1 = eta * t0
    t2 = eta * cosw

    rs = (cosw - t1) / (cosw + t1)
    rp = (t0 - t2) / (t0 + t2)

    (rs * rs + rp * rp) / 2
end

function sample_hemisphere_cos(normal::Vec3f, ruv::Vec2f)::Vec3f
    z = sqrt(ruv.y)
    r = sqrt(1 - z * z)
    phi = 2 * pif * ruv.x
    local_direction = Vec3f(r * cos(phi), r * sin(phi), z)
    transform_direction(basis_fromz(normal), local_direction)
end

function basis_fromz(v::Vec3f)::Mat3f
    # https://graphics.pixar.com/library/OrthonormalB/paper.pdf
    z = normalize(v)
    sign = copysign(1.0f0, z.z)
    a = -1.0f0 / (sign + z.z)
    b = z.x * z.y * a
    x = Vec3f(1.0f0 + sign * z.x * z.x * a, sign * b, -sign * z.x)
    y = Vec3f(b, sign + z.y * z.y * a, -z.y)
    return Mat3f(x, y, z)
end

end
