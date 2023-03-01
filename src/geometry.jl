#=
geometry:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-03-01
=#

#todo
module Geometry

using ..Math: Vec3f

struct Bbox3f
    min::Vec3f
    max::Vec3f

    Bbox3f() = new(
        Vec3f(typemax(Float32), typemax(Float32), typemax(Float32)),
        Vec3f(typemin(Float32), typemin(Float32), typemin(Float32)),
    )

    Bbox3f(min::Vec3f, max::Vec3f) = new(min, max)
end

point_bounds(p::Vec3f, r::Float32)::Bbox3f = Bbox3f(min(p .- r, p .+ r), max(p .- r, p .+ r))

line_bounds(p1::Vec3f, p2::Vec3f, r1::Float32, r2::Float32)::Bbox3f = Bbox3f(min(p1 .- r1, p2 .- r2), max(p1 .+ r1, p2 .+ r2))

triangle_bounds(p1::Vec3f, p2::Vec3f, p3::Vec3f)::Bbox3f = Bbox3f(min(p1, p2, p3), max(p1, p2, p3))

quad_bounds(p1::Vec3f, p2::Vec3f, p3::Vec3f, p4::Vec3f)::Bbox3f = Bbox3f(min(p1, p2, p3, p4), max(p1, p2, p3, p4))

end
