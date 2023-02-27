#=
sceneio:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-02-26
=#

module SceneIO

# using PlyIO
using JSON: parsefile
using ..Scene: SceneData, CameraData, TextureData, MaterialData, InstanceData,EnvironmentData
using ..Shape: ShapeData

function load_scene(filename::String)::SceneData
    scene = SceneData()
    json = parsefile(filename::AbstractString; inttype = Int32)
    if haskey(json, "cameras")
        cameras = json["cameras"]
        sizehint!(scene.cameras, length(cameras))
        for camera in cameras
            push!(scene.cameras, CameraData(camera))
        end
    end
    if haskey(json, "textures")
        textures = json["textures"]
        resize!(scene.textures, length(textures))
        Threads.@threads for i in 1:length(textures)
            scene.textures[i] = TextureData(textures[i])
        end
    end
    if haskey(json, "materials")
        materials = json["materials"]
        sizehint!(scene.materials, length(materials))
        for material in materials
            push!(scene.materials, MaterialData(material))
        end
    end
    if haskey(json, "shapes")
        shapes = json["shapes"]
        resize!(scene.shapes, length(shapes))
        Threads.@threads for i in 1:length(shapes)
            scene.shapes[i] = ShapeData(shapes[i])
        end
    end
    #todo(?) subdivs
    if haskey(json, "instances")
        instances = json["instances"]
        sizehint!(scene.instances, length(instances))
        for instance in instances
            push!(scene.instances, InstanceData(instance))
        end
    end
    if haskey(json, "environments")
        environments = json["environments"]
        sizehint!(scene.environments, length(environments))
        for environment in environments
            push!(scene.environments, EnvironmentData(environment))
        end
    end
    return scene
end

function add_environment(scene, params) end

end
