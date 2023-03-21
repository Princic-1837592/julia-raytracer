#=
math:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-02-26
=#

module Math

using StaticArrays: SVector
using Images: RGBA, RGB

const pif = Float32(pi)

const Vec2i = SVector{2,Int}
Vec2i() = Vec2i(0, 0)
const Vec3i = SVector{3,Int}
Vec3i() = Vec3i(0, 0, 0)
const Vec4i = SVector{4,Int}
Vec4i() = Vec4i(0, 0, 0, 0)

const Vec2f = SVector{2,Float32}
Vec2f() = Vec2f(0, 0)
const Vec3f = SVector{3,Float32}
Vec3f() = Vec3f(0, 0, 0)
const Vec4f = SVector{4,Float32}
Vec4f() = Vec4f(0, 0, 0, 0)
Vec4f(rgba::RGB) = Vec4f(rgba.r, rgba.g, rgba.b, 1)
Vec3f(vec4f::Vec4f) = Vec3f(vec4f[1], vec4f[2], vec4f[3])

const Vec4b = SVector{4,UInt8}
Vec4b() = Vec4b(0, 0, 0, 0)
Vec4b(rgba::RGBA) = Vec4b(
    UInt8(typemax(UInt8) * rgba.r),
    UInt8(typemax(UInt8) * rgba.g),
    UInt8(typemax(UInt8) * rgba.b),
    UInt8(typemax(UInt8) * rgba.alpha),
)
Vec4b(rgba::RGB) = Vec4b(
    UInt8(typemax(UInt8) * rgba.r),
    UInt8(typemax(UInt8) * rgba.g),
    UInt8(typemax(UInt8) * rgba.b),
    1,
)

const Frame3f = SVector{4,Vec3f}
function Frame3f(array::AbstractVector{Float32})
    if length(array) != 12
        x = Vec3f(1, 0, 0)
        y = Vec3f(0, 1, 0)
        z = Vec3f(0, 0, 1)
        o = Vec3f(0, 0, 0)
        return Frame3f(x, y, z, o)
    end
    x = Vec3f(array[1], array[2], array[3])
    y = Vec3f(array[4], array[5], array[6])
    z = Vec3f(array[7], array[8], array[9])
    o = Vec3f(array[10], array[11], array[12])
    Frame3f(x, y, z, o)
end
Frame3f() = Frame3f(Vec3f(), Vec3f(), Vec3f(), Vec3f())

const Mat3f = SVector{3,Vec3f}
Mat3f() = Mat3f(Vec3f(1, 0, 0), Vec3f(0, 1, 0), Vec3f(0, 0, 1))
Mat3f(frame::Frame3f) = Mat3f(frame[1], frame[2], frame[3])
Mat3f(xx, xy, xz, yx, yy, yz, zx, zy, zz) =
    Mat3f(Vec3f(xx, xy, xz), Vec3f(yx, yy, yz), Vec3f(zx, zy, zz))

dot(a::Vec3f, b::Vec3f) = sum(a .* b)

function normalize(a::Vec3f)::Vec3f
    l = sqrt(dot(a, a))
    if l != 0
        a / l
    else
        a
    end
end

transform_point(frame::Frame3f, point::Vec3f)::Vec3f =
    ((frame[1]) .* point[1] + (frame[2]) .* point[2] + (frame[3]) .* point[3]) .+ frame[4]

transform_vector(a::Frame3f, b::Vec3f)::Vec3f = a[1] * b[1] + a[2] * b[2] + a[3] * b[3]

transform_vector(a::Mat3f, b::Vec3f)::Vec3f = a * b

transform_direction(a::Frame3f, b::Vec3f)::Vec3f = normalize(transform_vector(a, b))

lerp(a::Vec4f, b::Vec4f, u::Float32) = @. a * (1 - u) + b * u

lerp(a::Vec3f, b::Vec3f, u::Float32) = @. a * (1 - u) + b * u

lerp(a::Vec3f, b::Vec3f, u::Vec3f) = @. a * (1 - u) + b * u

function inverse(frame::Frame3f, non_rigid::Bool = false)::Frame3f
    if non_rigid
        minv = inverse(rotation(frame))
        make_frame(minv, -(minv * frame[4]))
    else
        minv = transpose(rotation(frame))
        make_frame(minv, -(minv * frame[4]))
    end
end

Base.:*(m::Mat3f, f::Vec3f)::Vec3f = m[1] * f[1] + m[2] * f[2] + m[3] * f[3]

inverse(m::Mat3f)::Mat3f = adjoint(m) * (1.0f0 / determinant(m))

adjoint(m::Mat3f)::Mat3f =
    transpose(Mat3f(cross(m[2], m[3]), cross(m[3], m[1]), cross(m[1], m[2])))

cross(a::Vec3f, b::Vec3f)::Vec3f =
    Vec3f(a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1])

determinant(m::Mat3f)::Float32 = dot(m[1], cross(m[2], m[3]))

rotation(frame::Frame3f)::Mat3f = Mat3f(frame[1], frame[2], frame[3])

make_frame(m::Mat3f, t::Vec3f)::Frame3f = Frame3f(m[1], m[2], m[3], t)

transpose(m::Mat3f)::Mat3f =
    Mat3f(m[1][1], m[2][1], m[3][1], m[1][2], m[2][2], m[3][2], m[1][3], m[2][3], m[3][3])

transform_normal(a::Frame3f, b::Vec3f, non_rigid::Bool = false) =
    non_rigid ? transform_normal(rotation(a), b) : normalize(transform_vector(a, b))

orthonormalize(a::Vec3f, b::Vec3f)::Vec3f = normalize(a .- b .* dot(a, b))

transform_direction(a::Mat3f, b::Vec3f) = normalize(transform_vector(a, b))

reflect(w::Vec3f, n::Vec3f)::Vec3f = -w + 2 * dot(n, w) * n

function refract(w::Vec3f, n::Vec3f, inv_eta::Float32)::Vec3f
    cosine = dot(n, w)
    k = 1 + inv_eta * inv_eta * (cosine * cosine - 1)
    if k < 0
        return Vec3f(0, 0, 0)
    end
    return -w * inv_eta + (inv_eta * cosine - sqrt(k)) * n
end

math_length(a::Vec3f) = sqrt(dot(a, a))

distance_squared(a::Vec3f, b::Vec3f)::Float32 = dot(a .- b, a .- b)

function lookat_frame(eye::Vec3f, center::Vec3f, up::Vec3f, inv_xz::Bool = false)::Frame3f
    w = normalize(eye .- center)
    u = normalize(cross(up, w))
    v = normalize(cross(w, u))
    if inv_xz
        w = -w
        u = -u
    end
    return Frame3f(u, v, w, eye)
end

end
