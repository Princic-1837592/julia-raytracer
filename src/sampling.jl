#=
sampling:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-03-02
=#

module Sampling

using ..Math: Vec2f, pif, Vec3f, dot

function sample_disk(ruv::Vec2f)::Vec2f
    r = sqrt(ruv[2])
    phi = 2 * pif * ruv[1]
    Vec2f(cos(phi) * r, sin(phi) * r)
end

rand1f() = rand(Float32)

rand2f() = Vec2f(rand1f(), rand1f())

rand3f() = Vec3f(rand1f(), rand1f(), rand1f())

function sample_hemisphere_cos_pdf(normal::Vec3f, direction::Vec3f)::Float32
    cosw = dot(normal, direction)
    (cosw <= 0) ? 0 : cosw / pif
end

end
