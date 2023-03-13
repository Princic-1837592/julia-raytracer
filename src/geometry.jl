#=
geometry:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-03-01
=#

module Geometry

using ..Math:
    Vec3f,
    Frame3f,
    transform_point,
    transform_vector,
    cross,
    dot,
    Vec2f,
    normalize,
    math_length
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

struct Ray3f
    o    :: Vec3f
    d    :: Vec3f
    tmin :: Float32
    tmax :: Float32

    Ray3f() = new(Vec3f(0, 0, 0), Vec3f(0, 0, 1), ray_eps, typemax(Float32))
    Ray3f(o::Vec3f, d::Vec3f) = new(o, d, ray_eps, typemax(Float32))
    Ray3f(o::Vec3f, d::Vec3f, tmin::Float32, tmax::Float32) = new(o, d, tmin, tmax)
    Ray3f(ray::Ray3f) = new(ray.o, ray.d, ray.tmin, ray.tmax)
    Ray3f(ray::Ray3f, tmax::Float32) = new(ray.o, ray.d, ray.tmin, tmax)
end

struct PrimIntersection
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
    t0 = max(maximum(tmin), ray.tmin)
    t1 = min(minimum(tmax), ray.tmax)
    t1 *= 1.00000024
    t0 <= t1
end

function transform_ray(frame::Frame3f, ray::Ray3f)::Ray3f
    o = transform_point(frame, ray.o)
    d = transform_vector(frame, ray.d)
    Ray3f(o, d, ray.tmin, ray.tmax)
end

function intersect_point(ray::Ray3f, p::Vec3f, r::Float32)::PrimIntersection
    w = p .- ray.o
    t = dot(w, ray.d) / dot(ray.d, ray.d)

    if (t < ray.tmin || t > ray.tmax)
        return PrimIntersection()
    end

    rp = @. ray.o + ray.d * t
    prp = p .- rp
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
    v = p2 .- p1
    w = ray.o .- p1

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

    s = clamp(s, 0.0f0, 1.0f0)

    pr = @. ray.o + ray.d * t
    pl = @. p1 + (p2 - p1) * s
    prl = @. pr - pl

    d2 = dot(prl, prl)
    r = r1 * (1 - s) + r2 * s
    if (d2 > r * r)
        return PrimIntersection()
    end

    return PrimIntersection(Vec2f(s, sqrt(d2) / r), t, true)
end

function intersect_sphere(ray::Ray3f, p::Vec3f, r::Float32)::PrimIntersection
    a = dot(ray.d, ray.d)
    b = 2 * dot(ray.o .- p, ray.d)
    c = dot(ray.o .- p, ray.o .- p) - r * r

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
    u = atan(plocal[2], plocal[1]) / (2 * pif)
    if (u < 0)
        u += 1
    end
    v = acos(clamp(plocal[3], -1.0f0, 1.0f0)) / pif

    return PrimIntersection(Vec2f(u, v), t, true)
end

function intersect_triangle(ray::Ray3f, p1::Vec3f, p2::Vec3f, p3::Vec3f)::PrimIntersection
    edge1 = p2 .- p1
    edge2 = p3 .- p1

    pvec = cross(ray.d, edge2)
    det = dot(edge1, pvec)

    if (det == 0)
        return PrimIntersection()
    end
    inv_det::Float32 = 1.0f0 / det

    tvec = ray.o .- p1
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
        isec2 = PrimIntersection(1 .- isec2.uv, isec2.distance, isec2.hit)
    end
    if isec1.distance < isec2.distance
        isec1
    else
        isec2
    end
end

line_tangent(p1::Vec3f, p2::Vec3f) = normalize(p2 .- p1)

triangle_normal(p1::Vec3f, p2::Vec3f, p3::Vec3f) = normalize(cross(p2 .- p1, p3 .- p1))

triangle_area(p0::Vec3f, p1::Vec3f, p2::Vec3f)::Float32 =
    math_length(cross(p1 .- p0, p2 .- p0)) / 2

quad_normal(p1::Vec3f, p2::Vec3f, p3::Vec3f, p4::Vec3f) =
    normalize(triangle_normal(p1, p2, p4) + triangle_normal(p3, p4, p2))

quad_area(p0::Vec3f, p1::Vec3f, p2::Vec3f, p3::Vec3f)::Float32 =
    triangle_area(p0, p1, p3) + triangle_area(p2, p3, p1)

interpolate_line(p1, p2, u::Float32) = @. p1 * (1 - u) + p2 * u

interpolate_triangle(p1, p2, p3, uv::Vec2f) =
    @. p1 * (1 - uv[1] - uv[2]) + p2 * uv[1] + p3 * uv[2]

interpolate_quad(p1, p2, p3, p4, uv::Vec2f) =
    if (uv[1] + uv[2] <= 1)
        interpolate_triangle(p1, p2, p4, uv)
    else
        interpolate_triangle(p3, p4, p2, 1 .- uv)
    end

function triangle_tangents_fromuv(
    p1::Vec3f,
    p2::Vec3f,
    p3::Vec3f,
    uv1::Vec2f,
    uv2::Vec2f,
    uv3::Vec2f,
)::Tuple{Vec3f,Vec3f}
    #   // Follows the definition in http://www.terathon.com/code/tangent.html and
    #   // https://gist.github.com/aras-p/2843984
    #   // normal points up from texture space
    p = p2 .- p1
    q = p3 .- p1
    s = Vec2f(uv2[1] - uv1[1], uv3[1] - uv1[1])
    t = Vec2f(uv2[2] - uv1[2], uv3[2] - uv1[2])
    div = s[1] * t[2] - s[2] * t[1]

    if (div != 0)
        tu =
            Vec3f(
                t[2] * p[1] - t[1] * q[1],
                t[2] * p[2] - t[1] * q[2],
                t[2] * p[3] - t[1] * q[3],
            ) / div
        tv =
            Vec3f(
                s[1] * q[1] - s[2] * p[1],
                s[1] * q[2] - s[2] * p[2],
                s[1] * q[3] - s[2] * p[3],
            ) / div
        (tu, tv)
    else
        (Vec3f(1, 0, 0), Vec3f(0, 1, 0))
    end
end

function quad_tangents_fromuv(
    p1::Vec3f,
    p2::Vec3f,
    p3::Vec3f,
    p4::Vec3f,
    uv1::Vec2f,
    uv2::Vec2f,
    uv3::Vec2f,
    uv4::Vec2f,
    current_uv::Vec2f,
)::Tuple{Vec3f,Vec3f}
    if (current_uv[1] + current_uv[2] <= 1)
        triangle_tangents_fromuv(p1, p2, p4, uv1, uv2, uv4)
    else
        triangle_tangents_fromuv(p3, p4, p2, uv3, uv4, uv2)
    end
end

end
