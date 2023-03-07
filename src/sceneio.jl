#=
sceneio:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-02-26
=#

module SceneIO

using JSON: parsefile
using ..Scene:
    SceneData,
    CameraData,
    TextureData,
    MaterialData,
    InstanceData,
    EnvironmentData,
    load_texture
using ..Shape: load_shape, ShapeData
using ..Image: ImageData
using Images: save, RGBA, clamp01nan

#todo check all return values
function load_scene(filename::String, no_parallel::Bool)::SceneData
    dir = dirname(filename)
    scene = SceneData()
    json = parsefile(filename::AbstractString; inttype = Int)
    println("    loading cameras...")
    if haskey(json, "cameras")
        cameras = json["cameras"]
        sizehint!(scene.cameras, length(cameras))
        for camera in cameras
            push!(scene.cameras, CameraData(camera))
        end
    end
    println("    loading textures...")
    if haskey(json, "textures")
        textures = json["textures"]
        resize!(scene.textures, length(textures))
        if no_parallel
            for i in 1:length(textures)
                scene.textures[i] = TextureData()
                load_texture(joinpath(dir, textures[i]["uri"]), scene.textures[i])
            end
        else
            Threads.@threads for i in 1:length(textures)
                scene.textures[i] = TextureData()
                load_texture(joinpath(dir, textures[i]["uri"]), scene.textures[i])
            end
        end
    end
    println("    loading materials...")
    if haskey(json, "materials")
        materials = json["materials"]
        sizehint!(scene.materials, length(materials))
        for material in materials
            push!(scene.materials, MaterialData(material))
        end
    end
    println("    loading shapes...")
    if haskey(json, "shapes")
        shapes = json["shapes"]
        resize!(scene.shapes, length(shapes))
        if no_parallel
            for i in 1:length(shapes)
                scene.shapes[i] = ShapeData()
                load_shape(joinpath(dir, shapes[i]["uri"]), scene.shapes[i])
            end
        else
            Threads.@threads for i in 1:length(shapes)
                scene.shapes[i] = ShapeData()
                load_shape(joinpath(dir, shapes[i]["uri"]), scene.shapes[i])
            end
        end
    end
    #todo(?) subdivs
    println("    loading instances...")
    if haskey(json, "instances")
        instances = json["instances"]
        sizehint!(scene.instances, length(instances))
        for instance in instances
            push!(scene.instances, InstanceData(instance))
        end
    end
    println("    loading environments...")
    if haskey(json, "environments")
        environments = json["environments"]
        sizehint!(scene.environments, length(environments))
        for environment in environments
            push!(scene.environments, EnvironmentData(environment))
        end
    end
    #add_missing_camera
    #add_missing_radius
    return scene
end

function add_environment(scene, params) end

function save_image(filename::String, image::ImageData)
    ext = lowercase(splitext(filename)[2])
    if ext != ".png"
        error(ext, " is not supported")
    end
    matrix = Array{RGBA{Float32},2}(undef, image.height, image.width)
    for i in 1:(image.height)
        for j in 1:(image.width)
            vec4f = image.data[(i - 1) * image.width + j]
            matrix[i, j] = RGBA(vec4f[1], vec4f[2], vec4f[3], vec4f[4])
        end
    end
    save(filename, clamp01nan.(matrix))
end

end
