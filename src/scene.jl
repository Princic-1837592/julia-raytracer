#=
scene:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-01-03
=#

module Scene

using StaticArrays: SVector
using ..Math: Frame3f, Vec3f, Vec4f, Vec4b, Vec4i
using ..Shape: ShapeData
# using FileIO: load

const invalid_id = -1

struct CameraData
    frame        :: Frame3f
    orthographic :: Bool
    lens         :: Float32
    film         :: Float32
    aspect       :: Float32
    focus        :: Float32
    aperture     :: Float32
    name         :: String

    function CameraData(json)
        frame = Frame3f(Float32.(get(json, "frame", Vector())))
        orthographic = get(json, "orthographic", false)
        lens = get(json, "lens", 0.050)
        film = get(json, "film", 0.036)
        aspect = get(json, "aspect", 1.5)
        focus = get(json, "focus", 10000)
        aperture = get(json, "aperture", 0)
        name = get(json, "name", "")
        #todo lookat
        new(frame, orthographic, lens, film, aspect, focus, aperture, name)
    end
end

struct InstanceData
    frame    :: Frame3f
    shape    :: Int32
    material :: Int32

    function InstanceData(json)
        frame = Frame3f(Float32.(get(json, "frame", Vector())))
        shape = get(json, "shape", invalid_id - 1) + 1
        material = get(json, "material", invalid_id - 1) + 1
        #todo lookat
        new(frame, shape, material)
    end
end

struct EnvironmentData
    frame        :: Frame3f
    emission     :: Vec3f
    emission_tex :: Int32

    function EnvironmentData(json)
        frame = Frame3f(Float32.(get(json, "frame", Vector())))
        emission = get(json, "emission", Vec3f())
        emission_tex = get(json, "emission_tex", invalid_id - 1) + 1
        #todo lookat
        new(frame, emission, emission_tex)
    end
end

mutable struct TextureData
    width   :: Int32
    height  :: Int32
    linear  :: Bool
    pixelsf :: Array{Vec4f,1}
    pixelsb :: Array{Vec4b,1}

    TextureData() = new()
end

function load_texture(path::String, texture::TextureData)::Bool
    return true
    #     extension = lowercase(splitext(path)[2])
    #     if extension == ".hdr"
    #         #todo
    #     elseif extension == ".png"
    #         #         bytes = Array{UInt8}(undef, filesize(path))
    #         #         read!(path, bytes)
    #         #         println("bytes: ", length(bytes))
    #         img = load(path)
    #         println(length(img))
    #         (texture.width, texture.height) = size(img)
    #         println("width: $(texture.width) height: $(texture.height)")
    #         #         println("$(img[0]) $(img[0].r) $(img[0].g) $(img[0].b) $(img[0].alpha)")
    #         #         println(img[0, 0])
    #         texture.pixelsb = Array{Vec4b,1}(undef, texture.width * texture.height)
    #         for i in 1:(texture.width)
    #             for j in 1:(texture.height)
    #                 texture.pixelsb[i + (j - 1) * texture.width] =
    #                     Vec4b(img[i].r, img[i].g, img[i].b, img[i].alpha)
    #             end
    #         end
    #         return true
    #     else
    #         println("unknown texture format: ", extension)
    #     end
    #     return false
end

@enum MaterialType begin
    matte
    glossy
    reflective
    transparent
    refractive
    subsurface
    volumetric
    gltfpbr
end
MaterialTypes = Dict(
    "matte" => matte,
    "glossy" => glossy,
    "reflective" => reflective,
    "transparent" => transparent,
    "refractive" => refractive,
    "subsurface" => subsurface,
    "volumetric" => volumetric,
    "gltfpbr" => gltfpbr,
)

struct MaterialData
    type           :: MaterialType
    emission       :: Vec3f
    color          :: Vec3f
    roughness      :: Float32
    metallic       :: Float32
    ior            :: Float32
    scattering     :: Vec3f
    scanisotropy   :: Float32
    trdepth        :: Float32
    opacity        :: Float32
    emission_tex   :: Int32
    color_tex      :: Int32
    roughness_tex  :: Int32
    scattering_tex :: Int32
    normal_tex     :: Int32

    function MaterialData(json)
        type = get(MaterialTypes, get(json, "type", "matte"), matte)
        emission = get(json, "emission", Vec3f())
        color = get(json, "color", Vec3f())
        roughness = get(json, "roughness", 0)
        metallic = get(json, "metallic", 0)
        ior = get(json, "ior", 1.5)
        scattering = get(json, "scattering", Vec3f())
        scanisotropy = get(json, "scanisotropy", 0)
        trdepth = get(json, "trdepth", 0.01)
        opacity = get(json, "opacity", 1)
        emission_tex = get(json, "emission_tex", invalid_id - 1) + 1
        color_tex = get(json, "color_tex", invalid_id - 1) + 1
        roughness_tex = get(json, "roughness_tex", invalid_id - 1) + 1
        scattering_tex = get(json, "scattering_tex", invalid_id - 1) + 1
        normal_tex = get(json, "normal_tex", invalid_id - 1) + 1
        new(
            type,
            emission,
            color,
            roughness,
            metallic,
            ior,
            scattering,
            scanisotropy,
            trdepth,
            opacity,
            emission_tex,
            color_tex,
            roughness_tex,
            scattering_tex,
            normal_tex,
        )
    end
end

struct SubdivData
    quadspos         :: Array{Vec4i,1}
    quadsnorm        :: Array{Vec4i,1}
    quadstexcoord    :: Array{Vec4i,1}
    positions        :: Array{Vec3f,1}
    normals          :: Array{Vec3f,1}
    texcoords        :: Array{Vec3f,1}
    subdivisions     :: Int32
    catmullclark     :: Bool
    smooth           :: Bool
    displacement     :: Float32
    displacement_tex :: Int32
    shape            :: Int32
end

struct SceneData
    cameras      :: Array{CameraData,1}
    instances    :: Array{InstanceData,1}
    environments :: Array{EnvironmentData,1}
    shapes       :: Array{ShapeData,1}
    textures     :: Array{TextureData,1}
    materials    :: Array{MaterialData,1}
    subdivs      :: Array{SubdivData,1}
    #names are necessary??

    SceneData() = new(
        CameraData[],
        InstanceData[],
        EnvironmentData[],
        ShapeData[],
        TextureData[],
        MaterialData[],
        SubdivData[],
    )
end

function find_camera(scene::SceneData, name::String)::Int32
    if length(scene.cameras) == 0
        return invalid_id
    end
    for name in [name, "default", "camera", "camera0", "camera1"]
        for i in 1:length(scene.cameras)
            if scene.cameras[i].name == name
                return i
            end
        end
    end
    1
end

function add_sky(scene) end

end
