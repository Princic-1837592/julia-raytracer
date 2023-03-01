#=
bvh:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-01-03
=#

module Bvh

using ..Scene: SceneData
using ..Math: Vec3f

struct Bbox3f
    min::Vec3f
    max::Vec3f

    Bbox3f() = new(
        Vec3f(typemax(Float32), typemax(Float32), typemax(Float32)),
        Vec3f(typemin(Float32), typemin(Float32), typemin(Float32)),
    )
end

struct BvhNode
    bbox     :: Bbox3f
    start    :: Int32
    num      :: Int16
    axis     :: Int8
    internal :: Bool
end

struct BvhTree
    nodes      :: Array{BvhNode,1}
    primitives :: Array{Int32,1}
end

struct ShapeBvh
    bvh::BvhTree
end

struct SceneBvh
    bvh    :: BvhTree
    shapes :: Array{ShapeBvh,1}
end

function make_scene_bvh(scene::SceneData, params) end

end
