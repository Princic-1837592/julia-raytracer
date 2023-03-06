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

mutable struct BvhNode
    bbox     :: Bbox3f
    start    :: Int
    num      :: Int16
    axis     :: Int8
    internal :: Bool

    BvhNode() = new(Bbox3f(), 0, 0, 1, false)
end

struct BvhTree
    nodes      :: Vector{BvhNode}
    primitives :: Vector{Int}

    BvhTree() = new(BvhNode[], Int[])
end

mutable struct ShapeBvh
    bvh::BvhTree

    ShapeBvh() = new(BvhTree())
end

mutable struct SceneBvh
    bvh    :: BvhTree
    shapes :: Vector{ShapeBvh}

    SceneBvh() = new(BvhTree(), ShapeBvh[])
end

function make_scene_bvh(scene::SceneData, high_quality::Bool, no_parallel::Bool)::SceneBvh
    sbvh = SceneBvh()
    resize!(sbvh.shapes, length(scene.shapes))
    if no_parallel
        for i in 1:length(scene.shapes)
            sbvh.shapes[i] = make_shape_bvh(scene.shapes[i], high_quality)
        end
    else
        Threads.@threads for i in 1:length(scene.shapes)
            sbvh.shapes[i] = make_shape_bvh(scene.shapes[i], high_quality)
        end
    end
    bboxes = Vector{Bbox3f}(undef, length(scene.instances))
    for i in 1:length(bboxes)
        instance = scene.instances[i]
        bboxes[i] = if length(sbvh.shapes[instance.shape].bvh.nodes) == 0
            Bbox3f()
        else
            transform_bbox(instance.frame, sbvh.shapes[instance.shape].bvh.nodes[1].bbox)
        end
    end
    sbvh.bvh = make_bvh(bboxes, high_quality)
    sbvh
end

function make_shape_bvh(shape::ShapeData, high_quality::Bool)::ShapeBvh
    sbvh = ShapeBvh()
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

    sbvh.bvh = make_bvh(bboxes, high_quality)
    sbvh
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
            node.bbox = merge_bbox3f(node.bbox, bboxes[bvh.primitives[i]])
        end
        if right - left + 1 > BVH_MAX_PRIMS
            mid, axis = if high_quality
                #todo method does not exist yet
                #split_sah(centers, bboxes, left, right)
                (1, 1)
            else
                split_middle(bvh.primitives, bboxes, centers, left, right)
            end
            node.internal = true
            node.axis = axis
            node.num = 2
            node.start = length(bvh.nodes) + 1
            push!(bvh.nodes, BvhNode())
            push!(bvh.nodes, BvhNode())
            push!(stack, Vec3i(node.start, left, mid))
            push!(stack, Vec3i(node.start + 1, mid + 1, right))
        else
            node.internal = false
            node.start = left
            node.num = right - left + 1
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
        return div((left + right + 1), 2), 0
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
    ray_::Ray3f,
    find_any::Bool,
)::SceneIntersection
    bvh = sbvh.bvh
    if length(bvh.nodes) == 0
        return false
    end
    stack = Vector{Int}(undef, 128)
    fill!(stack, 0)
    node_cur = 1
    stack[node_cur] = 1
    node_cur += 1
    intersection = SceneIntersection()
    ray = Ray3f(ray_.o, ray_.d, ray_.tmin, ray_.tmax)
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
                ray.tmax = sintersection.distance
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
    ray_::Ray3f,
    find_any::Bool,
)::ShapeIntersection
    bvh = sbvh.bvh
    if length(bvh.nodes) == 0
        return ShapeIntersection()
    end
    stack = Vector{Int}(undef, 128)
    fill!(stack, 0)
    node_cur = 1
    stack[node_cur] = 1
    node_cur += 1
    intersection = ShapeIntersection()
    ray = Ray3f(ray_.o, ray_.d, ray_.tmin, ray_.tmax)
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
                ray.tmax = pintersection.distance
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
                ray.tmax = pintersection.distance
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
                ray.tmax = pintersection.distance
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
                ray.tmax = pintersection.distance
            end
        end
        if find_any && intersection.hit
            return intersection
        end
    end
    intersection
end

function verify_bvh(bvh)::Bool
    function verify_tree(tree)::Bool
        total = 0
        for node in tree.nodes
            if !node.internal
                total += node.num
            end
        end
        if total != length(tree.primitives)
            @printf("total %d != primitives %d\n", total, length(tree.primitives))
            return false
        end
        seen = Vector{Bool}(undef, total)
        for i in 1:length(seen)
            seen[i] = false
        end
        for node in tree.nodes
            if !node.internal
                for i in (node.start):(node.start + node.num - 1)
                    if seen[i]
                        println("seen $i")
                        return false
                    end
                    seen[i] = true
                end
            end
        end
        for i in 1:length(seen)
            if !seen[i]
                println("not seen $i")
                return false
            end
        end
        true
    end

    function print_bvh(tree::BvhTree)
        d = 10
        i = 0
        for node in tree.nodes
            if node.internal && i % d == 0
                @printf("%d %d %d %d ", node.start, node.num, node.internal, node.axis)
                @printf(
                    "%.5f %.5f %.5f ",
                    node.bbox.min[1],
                    node.bbox.min[2],
                    node.bbox.min[3]
                )
                @printf(
                    "%.5f %.5f %.5f\n",
                    node.bbox.max[1],
                    node.bbox.max[2],
                    node.bbox.max[3]
                )
                #                 if i % (2 * d) == 0
                #                     println()
                #                 end
            end
            i += 1
        end
    end
    #     print_bvh(bvh.bvh)
    #     for shape in bvh.shapes
    #         print_bvh(shape.bvh)
    #     end

    println("verifying bvh...")
    if !verify_tree(bvh.bvh)
        return false
    end
    for shape in bvh.shapes
        if !verify_tree(shape.bvh)
            return false
        end
    end

    true
end

end
