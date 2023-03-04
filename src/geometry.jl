#=
geometry:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-03-01
=#

module Geometry

using ..Math: Vec3f, Frame3f, transform_point, transform_vector, cross, dot, Vec2f
using Printf: @printf

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

mutable struct Ray3f
    o    :: Vec3f
    d    :: Vec3f
    tmin :: Float32
    tmax :: Float32

    Ray3f() = new(Vec3f(0, 0, 0), Vec3f(0, 0, 1), ray_eps, typemax(Float32))
    Ray3f(o::Vec3f, d::Vec3f) = new(o, d, ray_eps, typemax(Float32))
    Ray3f(o::Vec3f, d::Vec3f, tmin::Float32, tmax::Float32) = new(o, d, tmin, tmax)
end

mutable struct PrimIntersection
    uv       :: Vec2f
    distance :: Float32
    hit      :: Bool

    PrimIntersection() = new(Vec2f(0, 0), typemax(Float32), false)
    PrimIntersection(uv::Vec2f, distance::Float32, hit::Bool) = new(uv, distance, hit)
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
merge_bbox3f(bbox::Bbox3f, vector::Vec3f)::Bbox3f =
    Bbox3f(min.(bbox.min, vector), max.(bbox.max, vector))

merge_bbox3f(bbox1::Bbox3f, bbox2::Bbox3f)::Bbox3f =
    Bbox3f(min.(bbox1.min, bbox2.min), max.(bbox1.max, bbox2.max))

center(bbox::Bbox3f)::Vec3f = (bbox.min + bbox.max) / 2

function intersect_bbox(ray::Ray3f, ray_dinv::Vec3f, bbox::Bbox3f)::Bool
    it_min = (bbox.min - ray.o) .* ray_dinv
    it_max = (bbox.max - ray.o) .* ray_dinv
    tmin = min.(it_min, it_max)
    tmax = max.(it_min, it_max)
    t0 = max(findmax(tmin)[1], ray.tmin)
    t1 = min(findmin(tmax)[1], ray.tmax)
    t1 *= 1.00000024  # for double: 1.0000000000000004
    t0 <= t1
end

function transform_ray(frame::Frame3f, ray::Ray3f)::Ray3f
    o = transform_point(frame, ray.o)
    d = transform_vector(frame, ray.d)
    Ray3f(o, d, ray.tmin, ray.tmax)
end

function intersect_point(ray::Ray3f, p::Vec3f, r::Float32)::PrimIntersection
    w = p - ray.o
    t = dot(w, ray.d) / dot(ray.d, ray.d)

    if (t < ray.tmin || t > ray.tmax)
        return PrimIntersection()
    end

    rp = ray.o + ray.d * t
    prp = p - rp
    if (dot(prp, prp) > r * r)
        return PrimIntersection()
    end

    return PrimIntersection(Vec2f(0, 0), t, true)
end

function intersect_line(
    ray::Ray3f,
    p1::Vec3f,
    p2::Vec3f,
    r1::Float32,
    r2::Float32,
)::PrimIntersection
    u = ray.d
    v = p2 - p1
    w = ray.o - p1

    a = dot(u, u)
    b = dot(u, v)
    c = dot(v, v)
    d = dot(u, w)
    e = dot(v, w)
    det = a * c - b * b

    if (det == 0)
        return PrimIntersection()
    end

    t = (b * e - c * d) / det
    s = (a * e - b * d) / det

    if (t < ray.tmin || t > ray.tmax)
        return PrimIntersection()
    end

    s = clamp(s, 0.0, 1.0)

    pr = ray.o + ray.d * t
    pl = p1 + (p2 - p1) * s
    prl = pr - pl

    d2 = dot(prl, prl)
    r = r1 * (1 - s) + r2 * s
    if (d2 > r * r)
        return PrimIntersection()
    end

    return PrimIntersection(Vec2f(s, sqrt(d2) / r), t, true)
end

function intersect_sphere(ray::Ray3f, p::Vec3f, r::Float32)::PrimIntersection
    a = dot(ray.d, ray.d)
    b = 2 * dot(ray.o - p, ray.d)
    c = dot(ray.o - p, ray.o - p) - r * r

    dis = b * b - 4 * a * c
    if (dis < 0)
        return PrimIntersection()
    end

    t = (-b - sqrt(dis)) / (2 * a)

    if (t < ray.tmin || t > ray.tmax)
        return PrimIntersection()
    end

    t = (-b + sqrt(dis)) / (2 * a)

    if (t < ray.tmin || t > ray.tmax)
        return PrimIntersection()
    end

    plocal = ((ray.o + ray.d * t) - p) / r
    u = atan2(plocal[2], plocal[1]) / (2 * pif)
    if (u < 0)
        u += 1
    end
    v = acos(clamp(plocal[3], -1.0f0, 1.0f0)) / pif

    return PrimIntersection(Vec2f(u, v), t, true)
end

function intersect_triangle(ray::Ray3f, p1::Vec3f, p2::Vec3f, p3::Vec3f)::PrimIntersection
    edge1 = p2 - p1
    edge2 = p3 - p1

    pvec = cross(ray.d, edge2)
    det = dot(edge1, pvec)

    if (det == 0)
        return PrimIntersection()
    end
    inv_det::Float32 = 1.0 / det

    tvec = ray.o - p1
    u = dot(tvec, pvec) * inv_det
    if (u < 0 || u > 1)
        return PrimIntersection()
    end

    qvec = cross(tvec, edge1)
    v = dot(ray.d, qvec) * inv_det
    if (v < 0 || u + v > 1)
        return PrimIntersection()
    end

    t = dot(edge2, qvec) * inv_det
    if (t < ray.tmin || t > ray.tmax)
        return PrimIntersection()
    end

    PrimIntersection(Vec2f(u, v), t, true)
end

function intersect_quad(
    ray::Ray3f,
    p1::Vec3f,
    p2::Vec3f,
    p3::Vec3f,
    p4::Vec3f,
)::PrimIntersection
    if (p3 == p4)
        return intersect_triangle(ray, p1, p2, p4)
    end
    isec1 = intersect_triangle(ray, p1, p2, p4)
    isec2 = intersect_triangle(ray, p3, p4, p2)
    if (isec2.hit)
        isec2.uv = 1 .- isec2.uv
    end
    if isec1.distance < isec2.distance
        isec1
    else
        isec2
    end
end

end
