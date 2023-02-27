#=
math:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-02-26
=#

module Math

struct Vec2f
    x::Float32
    y::Float32
    Vec2f() = new(0, 0)
    Vec3f(x::Float32, y::Float32) = new(x, y)
end

struct Vec3f
    x::Float32
    y::Float32
    z::Float32
    Vec3f() = new(0, 0, 0)
    Vec3f(x::Float32, y::Float32, z::Float32) = new(x, y, z)
end

struct Vec4f
    x::Float32
    y::Float32
    z::Float32
    w::Float32
    Vec4f() = new(0, 0, 0, 0)
    Vec3f(x::Float32, y::Float32, z::Float32, w::Float32) = new(x, y, z, w)
end

struct Frame3f
    x::Vec3f
    y::Vec3f
    z::Vec3f
    o::Vec3f
    Frame3f() = new(Vec3f(), Vec3f(), Vec3f(), Vec3f())
    function Frame3f(array)
        x = Vec3f(array[1], array[2], array[3])
        y = Vec3f(array[4], array[5], array[6])
        z = Vec3f(array[7], array[8], array[9])
        o = Vec3f(array[10], array[11], array[12])
        new(x, y, z, o)
    end
end

struct Vec2i
    x::Int32
    y::Int32
    Vec2i() = new(0, 0)
end

struct Vec3i
    x::Int32
    y::Int32
    z::Int32
    Vec3i() = new(0, 0, 0)
end

struct Vec4i
    x::Int32
    y::Int32
    z::Int32
    w::Int32
    Vec4i() = new(0, 0, 0, 0)
end

struct Vec4b
    x::UInt8
    y::UInt8
    z::UInt8
    w::UInt8
    Vec4b() = new(0, 0, 0, 0)
end

end
