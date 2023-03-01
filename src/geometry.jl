#=
geometry:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-03-01
=#

module Geometry

using ..Math: Vec3f, Frame3f, transform_point

struct Bbox3f
    min::Vec3f
    max::Vec3f

    Bbox3f() = new(
        Vec3f(typemax(Float32), typemax(Float32), typemax(Float32)),
        Vec3f(typemin(Float32), typemin(Float32), typemin(Float32)),
    )

    Bbox3f(min::Vec3f, max::Vec3f) = new(min, max)
end

point_bounds(p::Vec3f, r::Float32)::Bbox3f =
    Bbox3f(min(p .- r, p .+ r), max(p .- r, p .+ r))

line_bounds(p1::Vec3f, p2::Vec3f, r1::Float32, r2::Float32)::Bbox3f =
    Bbox3f(min(p1 .- r1, p2 .- r2), max(p1 .+ r1, p2 .+ r2))

triangle_bounds(p1::Vec3f, p2::Vec3f, p3::Vec3f)::Bbox3f =
    Bbox3f(min(p1, p2, p3), max(p1, p2, p3))

quad_bounds(p1::Vec3f, p2::Vec3f, p3::Vec3f, p4::Vec3f)::Bbox3f =
    Bbox3f(min(p1, p2, p3, p4), max(p1, p2, p3, p4))

#yocto_geometry.cpp 455
function transform_bbox(frame::Frame3f, bbox::Bbox3f)::Bbox3f
    corners = [
        Vec3f(bbox.min[1], bbox.min[2], bbox.min[3]),
        Vec3f(bbox.min[1], bbox.min[2], bbox.max[3]),
        Vec3f(bbox.min[1], bbox.max[2], bbox.min[3]),
        Vec3f(bbox.min[1], bbox.max[2], bbox.max[3]),
        Vec3f(bbox.max[1], bbox.min[2], bbox.min[3]),
        Vec3f(bbox.max[1], bbox.min[2], bbox.max[3]),
        Vec3f(bbox.max[1], bbox.max[2], bbox.min[3]),
        Vec3f(bbox.max[1], bbox.max[2], bbox.max[3]),
    ]
    xformed = Bbox3f()
    for corner in corners
        xformed = merge_bbox3f_vec3f(xformed, transform_point(frame, corner))
    end
    return xformed
end

#yocto_geometry.cpp 410
merge_bbox3f_vec3f(bbox::Bbox3f, vector::Vec3f)::Bbox3f =
    Bbox3f(min(bbox.min, vector), max(bbox.max, vector))

end
