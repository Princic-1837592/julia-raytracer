#=
bvh:
- Julia version: 
- Author: Andrea
- Date: 2023-01-03
=#
include("shape.jl")


mutable struct ShapeBvh
    bvh::BvhTree
end

mutable struct SceneBvh{N}
    bvh::BvhTree
    shapes::SVector{N, ShapeBvh}
end

#todo aggiungere tipo di scene da scene.jl
function make_scene_bvh(scene, highquality::Bool, noparallel::Bool)
    sbvh::SceneBvh{scene.shapes.size}

end

