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
    @printf(
        "ruv: %.5f %.5f r: %.5f phi: %.5f cos(phi): %.5f sin(phi): %.5f\n",
        ruv[1],
        ruv[2],
        r,
        phi,
        cos(phi),
        sin(phi)
    )
    Vec2f(cos(phi) * r, sin(phi) * r)
end

# rand1f() = rand(Float32)
value::Float32 = 0.0f0
times = 0
function rand1f()::Float32
    global value
    global times
    times += 1
    value += 0.1
    if value > 1.0
        value = 0.0f0
    end
    #     @printf("returning %d: %.5f\n", times, value)
    return value
end
rand2f() = Vec2f(rand1f(), rand1f())

rand3f() = Vec3f(rand1f(), rand1f(), rand1f())

function sample_hemisphere_cos_pdf(normal::Vec3f, direction::Vec3f)::Float32
    cosw = dot(normal, direction)
    (cosw <= 0) ? 0 : cosw / pif
end

end
