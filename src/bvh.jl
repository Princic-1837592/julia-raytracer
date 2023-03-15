#=
bvh:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-01-03
=#

module Bvh

using ..Scene: SceneData, ShapeData
using ..Shape: ShapeIntersection, SceneIntersection
using ..Math: Vec3f, Frame3f, Vec3i, inverse
using ..Geometry:
    point_bounds,
    line_bounds,
    triangle_bounds,
    quad_bounds,
    Bbox3f,
    transform_bbox,
    merge_bbox3f,
    center,
    Ray3f,
    intersect_bbox,
    transform_ray,
    intersect_point,
    intersect_line,
    intersect_triangle,
    intersect_quad
using DataStructures: Stack
using Printf: @printf

const BVH_MAX_PRIMS = 4

struct BvhNode
    bbox     :: Bbox3f
    start    :: Int
    num      :: Int16
    axis     :: Int8
    internal :: Bool

    BvhNode() = new(Bbox3f(), 0, 0, 1, false)
    BvhNode(bbox::Bbox3f, start::Int, num, axis::Int8, internal::Bool) =
        new(bbox, start, num, axis, internal)
end

struct BvhTree
    nodes      :: Vector{BvhNode}
    primitives :: Vector{Int}

    BvhTree() = new(BvhNode[], Int[])
end

struct ShapeBvh
    bvh::BvhTree

    ShapeBvh(bvh::BvhTree) = new(bvh)
end

struct SceneBvh
    bvh    :: BvhTree
    shapes :: Vector{ShapeBvh}

    SceneBvh(bvh::BvhTree, shapes::Vector{ShapeBvh}) = new(bvh, shapes)
end

function make_scene_bvh(scene::SceneData, high_quality::Bool, no_parallel::Bool)::SceneBvh
    sbvh_shapes = Vector{ShapeBvh}(undef, length(scene.shapes))
    if no_parallel
        for i in 1:length(scene.shapes)
            sbvh_shapes[i] = make_shape_bvh(scene.shapes[i], high_quality)
        end
    else
        Threads.@threads for i in 1:length(scene.shapes)
            sbvh_shapes[i] = make_shape_bvh(scene.shapes[i], high_quality)
        end
    end
    bboxes = Vector{Bbox3f}(undef, length(scene.instances))
    for i in 1:length(bboxes)
        instance = scene.instances[i]
        bboxes[i] = if length(sbvh_shapes[instance.shape].bvh.nodes) == 0
            Bbox3f()
        else
            transform_bbox(instance.frame, sbvh_shapes[instance.shape].bvh.nodes[1].bbox)
        end
    end
    sbvh_bvh = make_bvh(bboxes, high_quality)
    SceneBvh(sbvh_bvh, sbvh_shapes)
end

function make_shape_bvh(shape::ShapeData, high_quality::Bool)::ShapeBvh
    bboxes = if length(shape.points) > 0
        result = Vector{Bbox3f}(undef, length(shape.points))
        for i in 1:length(shape.points)
            point = shape.points[i]
            result[i] = point_bounds(shape.positions[point], shape.radius[point])
        end
        result
    elseif length(shape.lines) > 0
        result = Vector{Bbox3f}(undef, length(shape.lines))
        for i in 1:length(shape.lines)
            line = shape.lines[i]
            result[i] = line_bounds(
                shape.positions[line[1]],
                shape.positions[line[2]],
                shape.radius[line[1]],
                shape.radius[line[2]],
            )
        end
        result
    elseif length(shape.triangles) > 0
        result = Vector{Bbox3f}(undef, length(shape.triangles))
        for i in 1:length(shape.triangles)
            triangle = shape.triangles[i]
            result[i] = triangle_bounds(
                shape.positions[triangle[1]],
                shape.positions[triangle[2]],
                shape.positions[triangle[3]],
            )
        end
        result
    elseif length(shape.quads) > 0
        result = Vector{Bbox3f}(undef, length(shape.quads))
        for i in 1:length(shape.quads)
            quad = shape.quads[i]
            result[i] = quad_bounds(
                shape.positions[quad[1]],
                shape.positions[quad[2]],
                shape.positions[quad[3]],
                shape.positions[quad[4]],
            )
        end
        result
    end

    ShapeBvh(make_bvh(bboxes, high_quality))
end

function make_bvh(bboxes::Vector{Bbox3f}, high_quality::Bool)::BvhTree
    bvh = BvhTree()
    sizehint!(bvh.nodes, length(bboxes) * 2)
    resize!(bvh.primitives, length(bboxes))
    for i in 1:length(bboxes)
        bvh.primitives[i] = i
    end
    centers = Vector{Vec3f}(undef, length(bboxes))
    for i in 1:length(bboxes)
        centers[i] = center(bboxes[i])
    end
    stack = Stack{Vec3i}()
    push!(stack, Vec3i(1, 1, length(bboxes)))
    push!(bvh.nodes, BvhNode())
    while length(stack) != 0
        node_id, left, right = pop!(stack)
        node = bvh.nodes[node_id]
        for i in left:right
            node = BvhNode(
                merge_bbox3f(node.bbox, bboxes[bvh.primitives[i]]),
                node.start,
                node.num,
                node.axis,
                node.internal,
            )
        end
        bvh.nodes[node_id] = node
        if right - left + 1 > BVH_MAX_PRIMS
            mid, axis = if high_quality
                #todo method does not exist yet
                #split_sah(centers, bboxes, left, right)
                error("not implemented")
                #                 (1, 1)
            else
                split_middle(bvh.primitives, bboxes, centers, left, right)
            end
            start = length(bvh.nodes) + 1
            bvh.nodes[node_id] = BvhNode(node.bbox, start, 2, axis, true)
            push!(bvh.nodes, BvhNode())
            push!(bvh.nodes, BvhNode())
            push!(stack, Vec3i(start, left, mid))
            push!(stack, Vec3i(start + 1, mid + 1, right))
        else
            bvh.nodes[node_id] =
                BvhNode(node.bbox, left, right - left + 1, node.axis, false)
        end
    end
    bvh
end

function split_middle(
    primitives::Vector{Int},
    bboxes::Vector{Bbox3f},
    centers::Vector{Vec3f},
    left::Int,
    right::Int,
)::Tuple{Int,Int8}
    cbbox = Bbox3f()
    for i in left:right
        cbbox = merge_bbox3f(cbbox, centers[primitives[i]])
    end
    csize = cbbox.max - cbbox.min
    if csize == Vec3f(0, 0, 0)
        return div((left + right + 1), 2), 1
    end
    axis = 1
    if csize[1] >= csize[2] && csize[1] >= csize[3]
        axis = 1
    end
    if csize[2] >= csize[1] && csize[2] >= csize[3]
        axis = 2
    end
    if csize[3] >= csize[1] && csize[3] >= csize[2]
        axis = 3
    end
    split = center(cbbox)[axis]
    middle =
        partition((primitive) -> centers[primitive][axis] < split, primitives, left, right)
    if middle < left || middle > right
        return (div(left + right + 1, 2), axis)
    end
    return (middle, axis)
end

function split_sah(
    primitives::Vector{Int},
    bboxes::Vector{Bbox3f},
    centers::Vector{Vec3f},
    left::Int,
    right::Int,
)::Tuple{Int,Int8}
    cbbox = Bbox3f()
    for i in left:right
        cbbox = merge_bbox3f(cbbox, centers[primitives[i]])
    end
    csize = cbbox.max - cbbox.min
    if csize == Vec3f(0, 0, 0)
        return div((left + right + 1), 2), 1
    end

    axis = 1
    nbins = 16
    split = 0.0f0
    min_cost = typemax(Float32)

    for saxis in 1:3
        for b in 1:(nbins - 1)
            bsplit = cbbox.min[saxis] + b * csize[saxis] / nbins
            left_bbox = Bbox3f()
            right_bbox = Bbox3f()
            left_nprims = 0
            right_nprims = 0
            for i in left:right
                if (centers[primitives[i]][saxis] < bsplit)
                    left_bbox = merge_bbox3f(left_bbox, bboxes[primitives[i]])
                    left_nprims += 1
                else
                    right_bbox = merge_bbox3f(right_bbox, bboxes[primitives[i]])
                    right_nprims += 1
                end
            end
            cost =
                1 +
                left_nprims * bbox_area(left_bbox) / bbox_area(cbbox) +
                right_nprims * bbox_area(right_bbox) / bbox_area(cbbox)
            if cost < min_cost
                min_cost = cost
                split = bsplit
                axis = saxis
            end
        end
    end

    middle =
        partition((primitive) -> centers[primitive][axis] < split, primitives, left, right)

    if middle == left || middle == right
        return div((left + right + 1), 2), axis
    end

    return (middle, axis)
end

function bbox_area(b::Bbox3f)::Float32
    size = b.max - b.min
    0.000000000001f0 + 2 * size[1] * size[2] + 2 * size[1] * size[3] + 2 * size[2] * size[3]
end

function partition(f::Function, a::Vector{T}, start::Int, stop::Int)::Int where {T}
    i = start
    j = stop
    while true
        while i <= stop && f(a[i])
            i += 1
        end
        while j >= start && !f(a[j])
            j -= 1
        end
        if i >= j
            break
        end
        a[i], a[j] = a[j], a[i]
    end
    j
end

function intersect_scene_bvh(
    sbvh::SceneBvh,
    scene::SceneData,
    ray::Ray3f,
    find_any::Bool,
    stack::Vector{Int32},
    sub_stack::Vector{Int32},
)::SceneIntersection
    bvh = sbvh.bvh
    if length(bvh.nodes) == 0
        return false
    end
    node_cur = 1
    stack[node_cur] = 1
    node_cur += 1
    intersection = SceneIntersection()
    ray_dinv = Vec3f(1 / ray.d[1], 1 / ray.d[2], 1 / ray.d[3])
    ray_dsign = Vec3i(if ray.d[1] < 0
        1
    else
        0
    end, if ray.d[2] < 0
        1
    else
        0
    end, if ray.d[3] < 0
        1
    else
        0
    end)
    while node_cur != 1
        node_cur -= 1
        node = bvh.nodes[stack[node_cur]]
        if !intersect_bbox(ray, ray_dinv, node.bbox)
            continue
        end
        if node.internal
            if ray_dsign[node.axis] == 0
                stack[node_cur] = node.start
                node_cur += 1
                stack[node_cur] = node.start + 1
                node_cur += 1
            else
                stack[node_cur] = node.start + 1
                node_cur += 1
                stack[node_cur] = node.start
                node_cur += 1
            end
        else
            for i in (node.start):(node.start + node.num - 1)
                instance = scene.instances[bvh.primitives[i]]
                inv_ray = transform_ray(inverse(instance.frame, true), ray)
                sintersection = intersect_shape_bvh(
                    sbvh.shapes[instance.shape],
                    scene.shapes[instance.shape],
                    inv_ray,
                    find_any,
                    sub_stack,
                )
                if !sintersection.hit
                    continue
                end
                intersection = SceneIntersection(
                    bvh.primitives[i],
                    sintersection.element,
                    sintersection.uv,
                    sintersection.distance,
                    true,
                )
                ray = Ray3f(ray, sintersection.distance)
            end
        end
        if find_any && intersection.hit
            return intersection
        end
    end
    intersection
end

function intersect_shape_bvh(
    sbvh::ShapeBvh,
    shape::ShapeData,
    ray::Ray3f,
    find_any::Bool,
    stack::Vector{Int32},
)::ShapeIntersection
    bvh = sbvh.bvh
    if length(bvh.nodes) == 0
        return ShapeIntersection()
    end
    node_cur = 1
    stack[node_cur] = 1
    node_cur += 1
    intersection = ShapeIntersection()
    ray_dinv = Vec3f(1 / ray.d[1], 1 / ray.d[2], 1 / ray.d[3])
    ray_dsign = Vec3i(if ray.d[1] < 0
        1
    else
        0
    end, if ray.d[2] < 0
        1
    else
        0
    end, if ray.d[3] < 0
        1
    else
        0
    end)
    while node_cur != 1
        node_cur -= 1
        node = bvh.nodes[stack[node_cur]]
        if !intersect_bbox(ray, ray_dinv, node.bbox)
            continue
        end
        if node.internal
            if ray_dsign[node.axis] == 0
                stack[node_cur] = node.start
                node_cur += 1
                stack[node_cur] = node.start + 1
                node_cur += 1
            else
                stack[node_cur] = node.start + 1
                node_cur += 1
                stack[node_cur] = node.start
                node_cur += 1
            end
        elseif length(shape.points) > 0
            for i in (node.start):(node.start + node.num - 1)
                p = shape.points[bvh.primitives[i]]
                pintersection = intersect_point(ray, shape.positions[p], shape.radius[p])
                if !pintersection.hit
                    continue
                end
                intersection = ShapeIntersection(
                    bvh.primitives[i],
                    pintersection.uv,
                    pintersection.distance,
                    true,
                )
                ray = Ray3f(ray, pintersection.distance)
            end
        elseif length(shape.lines) > 0
            for i in (node.start):(node.start + node.num - 1)
                l = shape.lines[bvh.primitives[i]]
                pintersection = intersect_line(
                    ray,
                    shape.positions[l[1]],
                    shape.positions[l[2]],
                    shape.radius[l[1]],
                    shape.radius[l[2]],
                )
                if !pintersection.hit
                    continue
                end
                intersection = ShapeIntersection(
                    bvh.primitives[i],
                    pintersection.uv,
                    pintersection.distance,
                    true,
                )
                ray = Ray3f(ray, pintersection.distance)
            end
        elseif length(shape.triangles) > 0
            for i in (node.start):(node.start + node.num - 1)
                t = shape.triangles[bvh.primitives[i]]
                pintersection = intersect_triangle(
                    ray,
                    shape.positions[t[1]],
                    shape.positions[t[2]],
                    shape.positions[t[3]],
                )
                if !pintersection.hit
                    continue
                end
                intersection = ShapeIntersection(
                    bvh.primitives[i],
                    pintersection.uv,
                    pintersection.distance,
                    true,
                )
                ray = Ray3f(ray, pintersection.distance)
            end
        elseif length(shape.quads) > 0
            for i in (node.start):(node.start + node.num - 1)
                q = shape.quads[bvh.primitives[i]]
                pintersection = intersect_quad(
                    ray,
                    shape.positions[q[1]],
                    shape.positions[q[2]],
                    shape.positions[q[3]],
                    shape.positions[q[4]],
                )
                if !pintersection.hit
                    continue
                end
                intersection = ShapeIntersection(
                    bvh.primitives[i],
                    pintersection.uv,
                    pintersection.distance,
                    true,
                )
                ray = Ray3f(ray, pintersection.distance)
            end
        end
        if find_any && intersection.hit
            return intersection
        end
    end
    intersection
end

function intersect_instance_bvh(
    sbvh::SceneBvh,
    scene::SceneData,
    instance_::Int,
    ray::Ray3f,
    sub_stack::Vector{Int32},
    find_any::Bool = false,
)::SceneIntersection
    instance = scene.instances[instance_]
    inv_ray = transform_ray(inverse(instance.frame, true), ray)
    intersection = intersect_shape_bvh(
        sbvh.shapes[instance.shape],
        scene.shapes[instance.shape],
        inv_ray,
        find_any,
        sub_stack,
    )
    if !intersection.hit
        return SceneIntersection()
    end
    SceneIntersection(
        instance_,
        intersection.element,
        intersection.uv,
        intersection.distance,
        true,
    )
end

end
