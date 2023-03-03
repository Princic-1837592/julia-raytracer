#=
geometry:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-03-01
=#

module Geometry

using ..Math: Vec3f, Frame3f, transform_point, transform_vector

struct Bbox3f
    min::Vec3f
    max::Vec3f

    Bbox3f() = new(
        Vec3f(typemax(Float32), typemax(Float32), typemax(Float32)),
        Vec3f(typemin(Float32), typemin(Float32), typemin(Float32)),
    )

    Bbox3f(min::Vec3f, max::Vec3f) = new(min, max)
end

const ray_eps::Float32 = 1e-4

struct Ray3f
    o    :: Vec3f
    d    :: Vec3f
    tmin :: Float32
    tmax :: Float32

    Ray3f() = new(Vec3f(0, 0, 0), Vec3f(0, 0, 1), ray_eps, typemax(Float32))
    Ray3f(o::Vec3f, d::Vec3f) = new(o, d, ray_eps, typemax(Float32))
    Ray3f(o::Vec3f, d::Vec3f, tmin::Float32, tmax::Float32) = new(o, d, tmin, tmax)
end

#todo-check if correct to use min. and max. here
point_bounds(p::Vec3f, r::Float32)::Bbox3f =
    Bbox3f(min.(p .- r, p .+ r), max.(p .- r, p .+ r))

line_bounds(p1::Vec3f, p2::Vec3f, r1::Float32, r2::Float32)::Bbox3f =
    Bbox3f(min.(p1 .- r1, p2 .- r2), max.(p1 .+ r1, p2 .+ r2))

triangle_bounds(p1::Vec3f, p2::Vec3f, p3::Vec3f)::Bbox3f =
    Bbox3f(min.(p1, p2, p3), max.(p1, p2, p3))

quad_bounds(p1::Vec3f, p2::Vec3f, p3::Vec3f, p4::Vec3f)::Bbox3f =
    Bbox3f(min.(p1, p2, p3, p4), max.(p1, p2, p3, p4))

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
        xformed = merge_bbox3f(xformed, transform_point(frame, corner))
    end
    return xformed
end

#yocto_geometry.cpp 410
#todo-check if correct to use min. and max. here
merge_bbox3f(bbox::Bbox3f, vector::Vec3f)::Bbox3f =
    Bbox3f(min.(bbox.min, vector), max.(bbox.max, vector))

merge_bbox3f(bbox1::Bbox3f, bbox2::Bbox3f)::Bbox3f =
    Bbox3f(min.(bbox1.min, bbox2.min), max(bbox1.max, bbox2.max))

center(bbox::Bbox3f)::Vec3f = (bbox.min + bbox.max) / 2

function intersect_bbox(ray::Ray3f, ray_dinv::Vec3f, bbox::Bbox3f)::Bool
    it_min = (bbox.min - ray.o) .* ray_dinv
    it_max = (bbox.max - ray.o) .* ray_dinv
    tmin = min.(it_min, it_max)
    tmax = max.(it_min, it_max)
    t0 = max(findmax(tmin)[1], ray.tmin)
    t1 = min(findmax(tmax)[1], ray.tmax)
    t1 *= 1.00000024  # for double: 1.0000000000000004
    t0 <= t1
end

function transform_ray(frame::Frame3f, ray::Ray3f)::Ray3f
    o = transform_point(frame, ray.o)
    d = transform_vector(frame, ray.d)
    Ray3f(o, d, ray.tmin, ray.tmax)
end

end
