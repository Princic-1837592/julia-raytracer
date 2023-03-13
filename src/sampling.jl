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

sample_uniform(size::Int, r::Float32)::Int = clamp(trunc(Int, r * size) + 1, 1, size)

sample_uniform_pdf(size::Int)::Float32 = 1 / size

function sample_discrete(cdf::Vector{Float32}, r::Float32)::Int
    r = clamp(r * last(cdf), 0.0f0, last(cdf) - 0.00001f0)
    idx = upper_bound(cdf, r)
    clamp(idx, 1, length(cdf))
end

sample_discrete_pdf(cdf::Vector{Float32}, idx::Int)::Float32 =
    if (idx == 1)
        cdf[1]
    else
        cdf[idx] - cdf[idx - 1]
    end

function upper_bound(cdf::Vector{Float32}, limit::Float32)::Int
    idx = 0
    l = 1
    r = length(cdf)
    while l <= r
        m = div((l + r), 2)
        if cdf[m] > limit
            idx = m
            r = m - 1
        else
            l = m + 1
        end
    end
    idx
end

sample_triangle(ruv::Vec2f)::Vec2f = return Vec2f(1 - sqrt(ruv[1]), ruv[2] * sqrt(ruv[1]))

end
