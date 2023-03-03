#=
bvh:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-01-03
=#

module Bvh

using ..Scene: SceneData, ShapeData
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
    transform_ray
using DataStructures: Stack
using Printf: @printf

#todo 4
const BVH_MAX_PRIMS = 1000000

mutable struct BvhNode
    bbox     :: Bbox3f
    start    :: Int32
    num      :: Int32
    axis     :: Int8
    internal :: Bool

    BvhNode() = new(Bbox3f(), 0, 0, 0, false)
end

struct BvhTree
    nodes      :: Array{BvhNode,1}
    primitives :: Array{Int32,1}

    BvhTree() = new(BvhNode[], Int32[])
end

mutable struct ShapeBvh
    bvh::BvhTree

    ShapeBvh() = new(BvhTree())
end

mutable struct SceneBvh
    bvh    :: BvhTree
    shapes :: Array{ShapeBvh,1}

    SceneBvh() = new(BvhTree(), ShapeBvh[])
end

#yocto_bvh.cpp 365
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
    bboxes = Array{Bbox3f,1}(undef, length(scene.instances))
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

#yocto_bvh.cpp 322
function make_shape_bvh(shape::ShapeData, high_quality::Bool)::ShapeBvh
    sbvh = ShapeBvh()
    bboxes = if length(shape.points) > 0
        result = Array{Bbox3f,1}(undef, length(shape.points))
        for i in 1:length(shape.points)
            point = shape.points[i]
            result[i] = point_bounds(shape.positions[point], shape.radius[point])
        end
        result
    elseif length(shape.lines) > 0
        result = Array{Bbox3f,1}(undef, length(shape.lines))
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
        result = Array{Bbox3f,1}(undef, length(shape.triangles))
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
        result = Array{Bbox3f,1}(undef, length(shape.quads))
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

#yocto_bvh.cpp 239
function make_bvh(bboxes::Array{Bbox3f,1}, high_quality::Bool)::BvhTree
    bvh = BvhTree()
    sizehint!(bvh.nodes, length(bboxes) * 2)
    resize!(bvh.primitives, length(bboxes))
    for i in 1:length(bboxes)
        bvh.primitives[i] = i
    end
    centers = Array{Vec3f,1}(undef, length(bboxes))
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
                (0, 0)
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
    primitives::Array{Int32,1},
    bboxes::Array{Bbox3f,1},
    centers::Array{Vec3f,1},
    left::Int32,
    right::Int32,
)::Tuple{Int32,Int8}
    cbbox = Bbox3f()
    for i in left:right
        cbbox = merge_bbox3f(cbbox, centers[primitives[i]])
    end
    csize = cbbox.max - cbbox.min
    if csize == Vec3f(0, 0, 0)
        return div((left + right + 1), 2), 0
    end
    axis = 0
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

function partition(f::Function, a::Array{T,1}, start::Int32, stop::Int32)::Int32 where {T}
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
)::Bool
    bvh = sbvh.bvh
    if length(bvh.nodes) == 0
        return false
    end
    stack = Array{Int32,1}(undef, 128)
    fill!(stack, 0)
    node_cur = 1
    stack[node_cur] = 1
    node_cur += 1
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
    hit = false
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
                if !intersect_shape_bvh(
                    sbvh.shapes[instance.shape],
                    scene.shapes[instance.shape],
                    inv_ray,
                    find_any,
                )
                    continue
                end
                if find_any
                    return true
                end
                hit = true
            end
        end
        if find_any && hit
            return true
        end
    end
    hit
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
        seen = Array{Bool,1}(undef, total)
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
