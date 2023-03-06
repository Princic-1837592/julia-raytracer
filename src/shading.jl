#=
shading:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-03-06
=#

#=
// Evaluate a diffuse BRDF lobe.
inline vec3f eval_matte(const vec3f& color, const vec3f& normal,
    const vec3f& outgoing, const vec3f& incoming) {
  if (dot(normal, incoming) * dot(normal, outgoing) <= 0) return {0, 0, 0};
  return color / pif * abs(dot(normal, incoming));
}

// Sample a diffuse BRDF lobe.
inline vec3f sample_matte(const vec3f& color, const vec3f& normal,
    const vec3f& outgoing, const vec2f& rn) {
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  return sample_hemisphere_cos(up_normal, rn);
}

// Pdf for diffuse BRDF lobe sampling.
inline float sample_matte_pdf(const vec3f& color, const vec3f& normal,
    const vec3f& outgoing, const vec3f& incoming) {
  if (dot(normal, incoming) * dot(normal, outgoing) <= 0) return 0;
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  return sample_hemisphere_cos_pdf(up_normal, incoming);
}

// Evaluate a specular BRDF lobe.
inline vec3f eval_glossy(const vec3f& color, float ior, float roughness,
    const vec3f& normal, const vec3f& outgoing, const vec3f& incoming) {
  if (dot(normal, incoming) * dot(normal, outgoing) <= 0) return {0, 0, 0};
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  auto F1        = fresnel_dielectric(ior, up_normal, outgoing);
  auto halfway   = normalize(incoming + outgoing);
  auto F         = fresnel_dielectric(ior, halfway, incoming);
  auto D         = microfacet_distribution(roughness, up_normal, halfway);
  auto G         = microfacet_shadowing(
              roughness, up_normal, halfway, outgoing, incoming);
  return color * (1 - F1) / pif * abs(dot(up_normal, incoming)) +
         vec3f{1, 1, 1} * F * D * G /
             (4 * dot(up_normal, outgoing) * dot(up_normal, incoming)) *
             abs(dot(up_normal, incoming));
}

// Sample a specular BRDF lobe.
inline vec3f sample_glossy(const vec3f& color, float ior, float roughness,
    const vec3f& normal, const vec3f& outgoing, float rnl, const vec2f& rn) {
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  if (rnl < fresnel_dielectric(ior, up_normal, outgoing)) {
    auto halfway  = sample_microfacet(roughness, up_normal, rn);
    auto incoming = reflect(outgoing, halfway);
    if (!same_hemisphere(up_normal, outgoing, incoming)) return {0, 0, 0};
    return incoming;
  } else {
    return sample_hemisphere_cos(up_normal, rn);
  }
}

// Pdf for specular BRDF lobe sampling.
inline float sample_glossy_pdf(const vec3f& color, float ior, float roughness,
    const vec3f& normal, const vec3f& outgoing, const vec3f& incoming) {
  if (dot(normal, incoming) * dot(normal, outgoing) <= 0) return 0;
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  auto halfway   = normalize(outgoing + incoming);
  auto F         = fresnel_dielectric(ior, up_normal, outgoing);
  return F * sample_microfacet_pdf(roughness, up_normal, halfway) /
             (4 * abs(dot(outgoing, halfway))) +
         (1 - F) * sample_hemisphere_cos_pdf(up_normal, incoming);
}

// Evaluate a metal BRDF lobe.
inline vec3f eval_reflective(const vec3f& color, float roughness,
    const vec3f& normal, const vec3f& outgoing, const vec3f& incoming) {
  if (dot(normal, incoming) * dot(normal, outgoing) <= 0) return {0, 0, 0};
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  auto halfway   = normalize(incoming + outgoing);
  auto F         = fresnel_conductor(
              reflectivity_to_eta(color), {0, 0, 0}, halfway, incoming);
  auto D = microfacet_distribution(roughness, up_normal, halfway);
  auto G = microfacet_shadowing(
      roughness, up_normal, halfway, outgoing, incoming);
  return F * D * G / (4 * dot(up_normal, outgoing) * dot(up_normal, incoming)) *
         abs(dot(up_normal, incoming));
}

// Sample a metal BRDF lobe.
inline vec3f sample_reflective(const vec3f& color, float roughness,
    const vec3f& normal, const vec3f& outgoing, const vec2f& rn) {
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  auto halfway   = sample_microfacet(roughness, up_normal, rn);
  auto incoming  = reflect(outgoing, halfway);
  if (!same_hemisphere(up_normal, outgoing, incoming)) return {0, 0, 0};
  return incoming;
}

// Pdf for metal BRDF lobe sampling.
inline float sample_reflective_pdf(const vec3f& color, float roughness,
    const vec3f& normal, const vec3f& outgoing, const vec3f& incoming) {
  if (dot(normal, incoming) * dot(normal, outgoing) <= 0) return 0;
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  auto halfway   = normalize(outgoing + incoming);
  return sample_microfacet_pdf(roughness, up_normal, halfway) /
         (4 * abs(dot(outgoing, halfway)));
}

// Evaluate a metal BRDF lobe.
inline vec3f eval_reflective(const vec3f& eta, const vec3f& etak,
    float roughness, const vec3f& normal, const vec3f& outgoing,
    const vec3f& incoming) {
  if (dot(normal, incoming) * dot(normal, outgoing) <= 0) return {0, 0, 0};
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  auto halfway   = normalize(incoming + outgoing);
  auto F         = fresnel_conductor(eta, etak, halfway, incoming);
  auto D         = microfacet_distribution(roughness, up_normal, halfway);
  auto G         = microfacet_shadowing(
              roughness, up_normal, halfway, outgoing, incoming);
  return F * D * G / (4 * dot(up_normal, outgoing) * dot(up_normal, incoming)) *
         abs(dot(up_normal, incoming));
}

// Sample a metal BRDF lobe.
inline vec3f sample_reflective(const vec3f& eta, const vec3f& etak,
    float roughness, const vec3f& normal, const vec3f& outgoing,
    const vec2f& rn) {
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  auto halfway   = sample_microfacet(roughness, up_normal, rn);
  return reflect(outgoing, halfway);
}

// Pdf for metal BRDF lobe sampling.
inline float sample_reflective_pdf(const vec3f& eta, const vec3f& etak,
    float roughness, const vec3f& normal, const vec3f& outgoing,
    const vec3f& incoming) {
  if (dot(normal, incoming) * dot(normal, outgoing) <= 0) return 0;
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  auto halfway   = normalize(outgoing + incoming);
  return sample_microfacet_pdf(roughness, up_normal, halfway) /
         (4 * abs(dot(outgoing, halfway)));
}

// Evaluate a delta metal BRDF lobe.
inline vec3f eval_reflective(const vec3f& color, const vec3f& normal,
    const vec3f& outgoing, const vec3f& incoming) {
  if (dot(normal, incoming) * dot(normal, outgoing) <= 0) return {0, 0, 0};
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  return fresnel_conductor(
      reflectivity_to_eta(color), {0, 0, 0}, up_normal, outgoing);
}

// Sample a delta metal BRDF lobe.
inline vec3f sample_reflective(
    const vec3f& color, const vec3f& normal, const vec3f& outgoing) {
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  return reflect(outgoing, up_normal);
}

// Pdf for delta metal BRDF lobe sampling.
inline float sample_reflective_pdf(const vec3f& color, const vec3f& normal,
    const vec3f& outgoing, const vec3f& incoming) {
  if (dot(normal, incoming) * dot(normal, outgoing) <= 0) return 0;
  return 1;
}

// Evaluate a delta metal BRDF lobe.
inline vec3f eval_reflective(const vec3f& eta, const vec3f& etak,
    const vec3f& normal, const vec3f& outgoing, const vec3f& incoming) {
  if (dot(normal, incoming) * dot(normal, outgoing) <= 0) return {0, 0, 0};
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  return fresnel_conductor(eta, etak, up_normal, outgoing);
}

// Sample a delta metal BRDF lobe.
inline vec3f sample_reflective(const vec3f& eta, const vec3f& etak,
    const vec3f& normal, const vec3f& outgoing) {
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  return reflect(outgoing, up_normal);
}

// Pdf for delta metal BRDF lobe sampling.
inline float sample_reflective_pdf(const vec3f& eta, const vec3f& etak,
    const vec3f& normal, const vec3f& outgoing, const vec3f& incoming) {
  if (dot(normal, incoming) * dot(normal, outgoing) <= 0) return 0;
  return 1;
}

// Evaluate a specular BRDF lobe.
inline vec3f eval_gltfpbr(const vec3f& color, float ior, float roughness,
    float metallic, const vec3f& normal, const vec3f& outgoing,
    const vec3f& incoming) {
  if (dot(normal, incoming) * dot(normal, outgoing) <= 0) return {0, 0, 0};
  auto reflectivity = lerp(
      eta_to_reflectivity(vec3f{ior, ior, ior}), color, metallic);
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  auto F1        = fresnel_schlick(reflectivity, up_normal, outgoing);
  auto halfway   = normalize(incoming + outgoing);
  auto F         = fresnel_schlick(reflectivity, halfway, incoming);
  auto D         = microfacet_distribution(roughness, up_normal, halfway);
  auto G         = microfacet_shadowing(
              roughness, up_normal, halfway, outgoing, incoming);
  return color * (1 - metallic) * (1 - F1) / pif *
             abs(dot(up_normal, incoming)) +
         F * D * G / (4 * dot(up_normal, outgoing) * dot(up_normal, incoming)) *
             abs(dot(up_normal, incoming));
}

// Sample a specular BRDF lobe.
inline vec3f sample_gltfpbr(const vec3f& color, float ior, float roughness,
    float metallic, const vec3f& normal, const vec3f& outgoing, float rnl,
    const vec2f& rn) {
  auto up_normal    = dot(normal, outgoing) <= 0 ? -normal : normal;
  auto reflectivity = lerp(
      eta_to_reflectivity(vec3f{ior, ior, ior}), color, metallic);
  if (rnl < mean(fresnel_schlick(reflectivity, up_normal, outgoing))) {
    auto halfway  = sample_microfacet(roughness, up_normal, rn);
    auto incoming = reflect(outgoing, halfway);
    if (!same_hemisphere(up_normal, outgoing, incoming)) return {0, 0, 0};
    return incoming;
  } else {
    return sample_hemisphere_cos(up_normal, rn);
  }
}

// Pdf for specular BRDF lobe sampling.
inline float sample_gltfpbr_pdf(const vec3f& color, float ior, float roughness,
    float metallic, const vec3f& normal, const vec3f& outgoing,
    const vec3f& incoming) {
  if (dot(normal, incoming) * dot(normal, outgoing) <= 0) return 0;
  auto up_normal    = dot(normal, outgoing) <= 0 ? -normal : normal;
  auto halfway      = normalize(outgoing + incoming);
  auto reflectivity = lerp(
      eta_to_reflectivity(vec3f{ior, ior, ior}), color, metallic);
  auto F = mean(fresnel_schlick(reflectivity, up_normal, outgoing));
  return F * sample_microfacet_pdf(roughness, up_normal, halfway) /
             (4 * abs(dot(outgoing, halfway))) +
         (1 - F) * sample_hemisphere_cos_pdf(up_normal, incoming);
}

// Evaluate a transmission BRDF lobe.
inline vec3f eval_transparent(const vec3f& color, float ior, float roughness,
    const vec3f& normal, const vec3f& outgoing, const vec3f& incoming) {
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  if (dot(normal, incoming) * dot(normal, outgoing) >= 0) {
    auto halfway = normalize(incoming + outgoing);
    auto F       = fresnel_dielectric(ior, halfway, outgoing);
    auto D       = microfacet_distribution(roughness, up_normal, halfway);
    auto G       = microfacet_shadowing(
              roughness, up_normal, halfway, outgoing, incoming);
    return vec3f{1, 1, 1} * F * D * G /
           (4 * dot(up_normal, outgoing) * dot(up_normal, incoming)) *
           abs(dot(up_normal, incoming));
  } else {
    auto reflected = reflect(-incoming, up_normal);
    auto halfway   = normalize(reflected + outgoing);
    auto F         = fresnel_dielectric(ior, halfway, outgoing);
    auto D         = microfacet_distribution(roughness, up_normal, halfway);
    auto G         = microfacet_shadowing(
                roughness, up_normal, halfway, outgoing, reflected);
    return color * (1 - F) * D * G /
           (4 * dot(up_normal, outgoing) * dot(up_normal, reflected)) *
           (abs(dot(up_normal, reflected)));
  }
}

// Sample a transmission BRDF lobe.
inline vec3f sample_transparent(const vec3f& color, float ior, float roughness,
    const vec3f& normal, const vec3f& outgoing, float rnl, const vec2f& rn) {
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  auto halfway   = sample_microfacet(roughness, up_normal, rn);
  if (rnl < fresnel_dielectric(ior, halfway, outgoing)) {
    auto incoming = reflect(outgoing, halfway);
    if (!same_hemisphere(up_normal, outgoing, incoming)) return {0, 0, 0};
    return incoming;
  } else {
    auto reflected = reflect(outgoing, halfway);
    auto incoming  = -reflect(reflected, up_normal);
    if (same_hemisphere(up_normal, outgoing, incoming)) return {0, 0, 0};
    return incoming;
  }
}

// Pdf for transmission BRDF lobe sampling.
inline float sample_tranparent_pdf(const vec3f& color, float ior,
    float roughness, const vec3f& normal, const vec3f& outgoing,
    const vec3f& incoming) {
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  if (dot(normal, incoming) * dot(normal, outgoing) >= 0) {
    auto halfway = normalize(incoming + outgoing);
    return fresnel_dielectric(ior, halfway, outgoing) *
           sample_microfacet_pdf(roughness, up_normal, halfway) /
           (4 * abs(dot(outgoing, halfway)));
  } else {
    auto reflected = reflect(-incoming, up_normal);
    auto halfway   = normalize(reflected + outgoing);
    auto d         = (1 - fresnel_dielectric(ior, halfway, outgoing)) *
             sample_microfacet_pdf(roughness, up_normal, halfway);
    return d / (4 * abs(dot(outgoing, halfway)));
  }
}

// Evaluate a delta transmission BRDF lobe.
inline vec3f eval_transparent(const vec3f& color, float ior,
    const vec3f& normal, const vec3f& outgoing, const vec3f& incoming) {
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  if (dot(normal, incoming) * dot(normal, outgoing) >= 0) {
    return vec3f{1, 1, 1} * fresnel_dielectric(ior, up_normal, outgoing);
  } else {
    return color * (1 - fresnel_dielectric(ior, up_normal, outgoing));
  }
}

// Sample a delta transmission BRDF lobe.
inline vec3f sample_transparent(const vec3f& color, float ior,
    const vec3f& normal, const vec3f& outgoing, float rnl) {
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  if (rnl < fresnel_dielectric(ior, up_normal, outgoing)) {
    return reflect(outgoing, up_normal);
  } else {
    return -outgoing;
  }
}

// Pdf for delta transmission BRDF lobe sampling.
inline float sample_tranparent_pdf(const vec3f& color, float ior,
    const vec3f& normal, const vec3f& outgoing, const vec3f& incoming) {
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  if (dot(normal, incoming) * dot(normal, outgoing) >= 0) {
    return fresnel_dielectric(ior, up_normal, outgoing);
  } else {
    return 1 - fresnel_dielectric(ior, up_normal, outgoing);
  }
}

// Evaluate a refraction BRDF lobe.
inline vec3f eval_refractive(const vec3f& color, float ior, float roughness,
    const vec3f& normal, const vec3f& outgoing, const vec3f& incoming) {
  auto entering  = dot(normal, outgoing) >= 0;
  auto up_normal = entering ? normal : -normal;
  auto rel_ior   = entering ? ior : (1 / ior);
  if (dot(normal, incoming) * dot(normal, outgoing) >= 0) {
    auto halfway = normalize(incoming + outgoing);
    auto F       = fresnel_dielectric(rel_ior, halfway, outgoing);
    auto D       = microfacet_distribution(roughness, up_normal, halfway);
    auto G       = microfacet_shadowing(
              roughness, up_normal, halfway, outgoing, incoming);
    return vec3f{1, 1, 1} * F * D * G /
           abs(4 * dot(normal, outgoing) * dot(normal, incoming)) *
           abs(dot(normal, incoming));
  } else {
    auto halfway = -normalize(rel_ior * incoming + outgoing) *
                   (entering ? 1.0f : -1.0f);
    auto F = fresnel_dielectric(rel_ior, halfway, outgoing);
    auto D = microfacet_distribution(roughness, up_normal, halfway);
    auto G = microfacet_shadowing(
        roughness, up_normal, halfway, outgoing, incoming);
    // [Walter 2007] equation 21
    return vec3f{1, 1, 1} *
           abs((dot(outgoing, halfway) * dot(incoming, halfway)) /
               (dot(outgoing, normal) * dot(incoming, normal))) *
           (1 - F) * D * G /
           pow(rel_ior * dot(halfway, incoming) + dot(halfway, outgoing),
               2.0f) *
           abs(dot(normal, incoming));
  }
}

// Sample a refraction BRDF lobe.
inline vec3f sample_refractive(const vec3f& color, float ior, float roughness,
    const vec3f& normal, const vec3f& outgoing, float rnl, const vec2f& rn) {
  auto entering  = dot(normal, outgoing) >= 0;
  auto up_normal = entering ? normal : -normal;
  auto halfway   = sample_microfacet(roughness, up_normal, rn);
  // auto halfway = sample_microfacet(roughness, up_normal, outgoing, rn);
  if (rnl < fresnel_dielectric(entering ? ior : (1 / ior), halfway, outgoing)) {
    auto incoming = reflect(outgoing, halfway);
    if (!same_hemisphere(up_normal, outgoing, incoming)) return {0, 0, 0};
    return incoming;
  } else {
    auto incoming = refract(outgoing, halfway, entering ? (1 / ior) : ior);
    if (same_hemisphere(up_normal, outgoing, incoming)) return {0, 0, 0};
    return incoming;
  }
}

// Pdf for refraction BRDF lobe sampling.
inline float sample_refractive_pdf(const vec3f& color, float ior,
    float roughness, const vec3f& normal, const vec3f& outgoing,
    const vec3f& incoming) {
  auto entering  = dot(normal, outgoing) >= 0;
  auto up_normal = entering ? normal : -normal;
  auto rel_ior   = entering ? ior : (1 / ior);
  if (dot(normal, incoming) * dot(normal, outgoing) >= 0) {
    auto halfway = normalize(incoming + outgoing);
    return fresnel_dielectric(rel_ior, halfway, outgoing) *
           sample_microfacet_pdf(roughness, up_normal, halfway) /
           //  sample_microfacet_pdf(roughness, up_normal, halfway, outgoing) /
           (4 * abs(dot(outgoing, halfway)));
  } else {
    auto halfway = -normalize(rel_ior * incoming + outgoing) *
                   (entering ? 1.0f : -1.0f);
    // [Walter 2007] equation 17
    return (1 - fresnel_dielectric(rel_ior, halfway, outgoing)) *
           sample_microfacet_pdf(roughness, up_normal, halfway) *
           //  sample_microfacet_pdf(roughness, up_normal, halfway, outgoing) /
           abs(dot(halfway, incoming)) /  // here we use incoming as from pbrt
           pow(rel_ior * dot(halfway, incoming) + dot(halfway, outgoing), 2.0f);
  }
}

// Evaluate a delta refraction BRDF lobe.
inline vec3f eval_refractive(const vec3f& color, float ior, const vec3f& normal,
    const vec3f& outgoing, const vec3f& incoming) {
  if (abs(ior - 1) < 1e-3)
    return dot(normal, incoming) * dot(normal, outgoing) <= 0 ? vec3f{1, 1, 1}
                                                              : vec3f{0, 0, 0};
  auto entering  = dot(normal, outgoing) >= 0;
  auto up_normal = entering ? normal : -normal;
  auto rel_ior   = entering ? ior : (1 / ior);
  if (dot(normal, incoming) * dot(normal, outgoing) >= 0) {
    return vec3f{1, 1, 1} * fresnel_dielectric(rel_ior, up_normal, outgoing);
  } else {
    return vec3f{1, 1, 1} * (1 / (rel_ior * rel_ior)) *
           (1 - fresnel_dielectric(rel_ior, up_normal, outgoing));
  }
}

// Sample a delta refraction BRDF lobe.
inline vec3f sample_refractive(const vec3f& color, float ior,
    const vec3f& normal, const vec3f& outgoing, float rnl) {
  if (abs(ior - 1) < 1e-3) return -outgoing;
  auto entering  = dot(normal, outgoing) >= 0;
  auto up_normal = entering ? normal : -normal;
  auto rel_ior   = entering ? ior : (1 / ior);
  if (rnl < fresnel_dielectric(rel_ior, up_normal, outgoing)) {
    return reflect(outgoing, up_normal);
  } else {
    return refract(outgoing, up_normal, 1 / rel_ior);
  }
}

// Pdf for delta refraction BRDF lobe sampling.
inline float sample_refractive_pdf(const vec3f& color, float ior,
    const vec3f& normal, const vec3f& outgoing, const vec3f& incoming) {
  if (abs(ior - 1) < 1e-3)
    return dot(normal, incoming) * dot(normal, outgoing) < 0 ? 1.0f : 0.0f;
  auto entering  = dot(normal, outgoing) >= 0;
  auto up_normal = entering ? normal : -normal;
  auto rel_ior   = entering ? ior : (1 / ior);
  if (dot(normal, incoming) * dot(normal, outgoing) >= 0) {
    return fresnel_dielectric(rel_ior, up_normal, outgoing);
  } else {
    return (1 - fresnel_dielectric(rel_ior, up_normal, outgoing));
  }
}

// Evaluate a translucent BRDF lobe.
inline vec3f eval_translucent(const vec3f& color, const vec3f& normal,
    const vec3f& outgoing, const vec3f& incoming) {
  if (dot(normal, incoming) * dot(normal, outgoing) >= 0) return {0, 0, 0};
  return color / pif * abs(dot(normal, incoming));
}

// Sample a translucency BRDF lobe.
inline vec3f sample_translucent(const vec3f& color, const vec3f& normal,
    const vec3f& outgoing, const vec2f& rn) {
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  return sample_hemisphere_cos(-up_normal, rn);
}

// Pdf for translucency BRDF lobe sampling.
inline float sample_translucent_pdf(const vec3f& color, const vec3f& normal,
    const vec3f& outgoing, const vec3f& incoming) {
  if (dot(normal, incoming) * dot(normal, outgoing) >= 0) return 0;
  auto up_normal = dot(normal, outgoing) <= 0 ? -normal : normal;
  return sample_hemisphere_cos_pdf(-up_normal, incoming);
}

// Evaluate a passthrough BRDF lobe.
inline vec3f eval_passthrough(const vec3f& color, const vec3f& normal,
    const vec3f& outgoing, const vec3f& incoming) {
  if (dot(normal, incoming) * dot(normal, outgoing) >= 0) {
    return vec3f{0, 0, 0};
  } else {
    return vec3f{1, 1, 1};
  }
}

// Sample a passthrough BRDF lobe.
inline vec3f sample_passthrough(
    const vec3f& color, const vec3f& normal, const vec3f& outgoing) {
  return -outgoing;
}

// Pdf for passthrough BRDF lobe sampling.
inline float sample_passthrough_pdf(const vec3f& color, const vec3f& normal,
    const vec3f& outgoing, const vec3f& incoming) {
  if (dot(normal, incoming) * dot(normal, outgoing) >= 0) {
    return 0;
  } else {
    return 1;
  }
}

// Convert mean-free-path to transmission
inline vec3f mfp_to_transmission(const vec3f& mfp, float depth) {
  return exp(-depth / mfp);
}

// Evaluate transmittance
inline vec3f eval_transmittance(const vec3f& density, float distance) {
  return exp(-density * distance);
}

// Sample a distance proportionally to transmittance
inline float sample_transmittance(
    const vec3f& density, float max_distance, float rl, float rd) {
  auto channel  = clamp((int)(rl * 3), 0, 2);
  auto distance = (density[channel] == 0) ? flt_max
                                          : -log(1 - rd) / density[channel];
  return min(distance, max_distance);
}

// Pdf for distance sampling
inline float sample_transmittance_pdf(
    const vec3f& density, float distance, float max_distance) {
  if (distance < max_distance) {
    return sum(density * exp(-density * distance)) / 3;
  } else {
    return sum(exp(-density * max_distance)) / 3;
  }
}

// Evaluate phase function
inline float eval_phasefunction(
    float anisotropy, const vec3f& outgoing, const vec3f& incoming) {
  auto cosine = -dot(outgoing, incoming);
  auto denom  = 1 + anisotropy * anisotropy - 2 * anisotropy * cosine;
  return (1 - anisotropy * anisotropy) / (4 * pif * denom * sqrt(denom));
}

// Sample phase function
inline vec3f sample_phasefunction(
    float anisotropy, const vec3f& outgoing, const vec2f& rn) {
  auto cos_theta = 0.0f;
  if (abs(anisotropy) < 1e-3f) {
    cos_theta = 1 - 2 * rn.y;
  } else {
    auto square = (1 - anisotropy * anisotropy) /
                  (1 + anisotropy - 2 * anisotropy * rn.y);
    cos_theta = (1 + anisotropy * anisotropy - square * square) /
                (2 * anisotropy);
  }

  auto sin_theta      = sqrt(max(0.0f, 1 - cos_theta * cos_theta));
  auto phi            = 2 * pif * rn.x;
  auto local_incoming = vec3f{
      sin_theta * cos(phi), sin_theta * sin(phi), cos_theta};
  return basis_fromz(-outgoing) * local_incoming;
}

// Pdf for phase function sampling
inline float sample_phasefunction_pdf(
    float anisotropy, const vec3f& outgoing, const vec3f& incoming) {
  return eval_phasefunction(anisotropy, outgoing, incoming);
}
=#