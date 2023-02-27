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

const invalid_id = -1

struct CameraData
    frame        :: Frame3f
    orthographic :: Bool
    lens         :: Float32
    film         :: Float32
    aspect       :: Float32
    focus        :: Float32
    aperture     :: Float32
    function CameraData(json)
        frame = Frame3f(Float32.(get(json, "frame", Vector())))
        orthographic = get(json, "orthographic", false)
        lens = get(json, "lens", 0.050)
        film = get(json, "film", 0.036)
        aspect = get(json, "aspect", 1.5)
        focus = get(json, "focus", 10000)
        aperture = get(json, "aperture", 0)
        #todo lookat
        new(frame, orthographic, lens, film, aspect, focus, aperture)
    end
end

struct InstanceData
    frame    :: Frame3f
    shape    :: Int32
    material :: Int32
end

struct EnvironmentData
    frame        :: Frame3f
    emission     :: Vec3f
    emission_tex :: Int32
end

struct TextureData
    width   :: Int32
    height  :: Int32
    linear  :: Bool
    pixelsf :: Array{Vec4f,1}
    pixelsb :: Array{Vec4b,1}
    function TextureData(json)
        #todo yocto_sceneio.cpp line 1734
        new(0, 0, false, Array{Vec4f,1}(), Array{Vec4b,1}())
    end
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

function find_camera(scene, params) end

function add_sky(scene) end

end
