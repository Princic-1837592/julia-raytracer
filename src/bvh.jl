#=
bvh:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-01-03
=#

module Bvh

using ..Scene: SceneData, ShapeData
using ..Math: Vec3f, Frame3f
using ..Geometry: point_bounds, line_bounds, triangle_bounds, quad_bounds, Bbox3f

struct BvhNode
    bbox     :: Bbox3f
    start    :: Int32
    num      :: Int16
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
            transform_bbox(instance.frame, sbvh.shapes[instance.shape].bvh.nodes[0].bbox)
        end
    end
    sbvh.bvh = make_bvh(bboxes, high_quality)
    sbvh
end

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

function transform_bbox(frame::Frame3f, bbox::Bbox3f)::Bbox3f
    Bbox3f()
end

function make_bvh(bboxes::Array{Bbox3f,1}, high_quality::Bool)::BvhTree
    BvhTree()
end

end
