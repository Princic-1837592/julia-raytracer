#=
math:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-02-26
=#

module Math
using StaticArrays: SVector

const Vec2i = SVector{2,Int32}
Vec2i() = Vec2i(0, 0)
const Vec3i = SVector{3,Int32}
Vec3i() = Vec3i(0, 0, 0)
const Vec4i = SVector{4,Int32}
Vec4i() = Vec4i(0, 0, 0, 0)

const Vec2f = SVector{2,Float32}
Vec2f() = Vec2f(0, 0)
const Vec3f = SVector{3,Float32}
Vec3f() = Vec3f(0, 0, 0)
const Vec4f = SVector{4,Float32}
Vec4f() = Vec4f(0, 0, 0, 0)

const Vec4b = SVector{4,UInt8}
Vec4b() = Vec4b(0, 0, 0, 0)

const Frame3f = SVector{4,Vec3f}
function Frame3f(array::Vector{Float32})
    if length(array) != 12
        array = Vector([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
    end
    x = Vec3f(array[1], array[2], array[3])
    y = Vec3f(array[4], array[5], array[6])
    z = Vec3f(array[7], array[8], array[9])
    o = Vec3f(array[10], array[11], array[12])
    Frame3f(x, y, z, o)
end
Frame3f() = Frame3f(Vec3f(), Vec3f(), Vec3f(), Vec3f())

#yocto_math.h 2233
transform_point(frame::Frame3f, point::Vec3f)::Vec3f =
    ((frame.x) .* point[1] + (frame.y) .* point[2] + (frame.z) .* point[3]) .+ frame.o

end
