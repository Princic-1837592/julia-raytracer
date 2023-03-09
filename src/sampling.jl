#=
sampling:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-03-02
=#

module Sampling

using ..Math: Vec2f, pif, Vec3f, dot
using Printf: @printf

function sample_disk(ruv::Vec2f)::Vec2f
    r = sqrt(ruv[2])
    phi = 2 * pif * ruv[1]
    #     @printf(
    #         "ruv: %.5f %.5f r: %.5f phi: %.5f cos(phi): %.5f sin(phi): %.5f\n",
    #         ruv[1],
    #         ruv[2],
    #         r,
    #         phi,
    #         cos(phi),
    #         sin(phi)
    #     )
    Vec2f(cos(phi) * r, sin(phi) * r)
end

rand1f() = rand(Float32)
# value::Float32 = 0.0f0
# times = 0
# function rand1f()::Float32
#     global value
#     global times
#     times += 1
#     value += 0.1
#     if value > 1.0
#         value = 0.0f0
#     end
#     #     @printf("returning %d: %.5f\n", times, value)
#     return value
# end
rand2f() = Vec2f(rand1f(), rand1f())

rand3f() = Vec3f(rand1f(), rand1f(), rand1f())

function sample_hemisphere_cos_pdf(normal::Vec3f, direction::Vec3f)::Float32
    cosw = dot(normal, direction)
    (cosw <= 0) ? 0 : cosw / pif
end

sample_uniform(size::Int, r::Float32)::Int = clamp(trunc(Int, r * size), 1, size)

sample_uniform_pdf(size::Int)::Float32 = 1 / size

function sample_discrete(cdf::Vector{Float32}, r::Float32)::Int
    r = clamp(r * last(cdf), 0.0f0, last(cdf) - 0.00001f0)
    #todo
    idx = upper_bound(cdf, r)
    clamp(idx, 1, length(cdf))
end

function upper_bound(cdf::Vector{Float32}, r::Float32)::Int
    idx = 0
    for i in 1:length(cdf)
        if cdf[i] > r
            idx = i
            break
        end
    end
    idx
end

sample_discrete_pdf(cdf::Vector{Float32}, idx::Int)::Float32 =
    if (idx == 1)
        cdf[1]
    else
        cdf[idx] - cdf[idx - 1]
    end

end
