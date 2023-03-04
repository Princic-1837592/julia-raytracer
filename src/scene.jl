#=
scene:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-01-03
=#

module Scene

using StaticArrays: SVector
using ..Math:
    Frame3f,
    Vec2f,
    Vec3f,
    Vec4f,
    Vec4b,
    Vec4i,
    normalize,
    transform_point,
    transform_direction
using ..Shape: ShapeData
using ..Geometry: Ray3f
using ImageMagick: load, load_
using Printf: @printf

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
        frame = Frame3f(Float32.(get(json, "frame", Vector{Float32}(undef, 0))))
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
    pixelsf :: Vector{Vec4f}
    pixelsb :: Vector{Vec4b}

    TextureData() = new()
end

function load_texture(path::String, texture::TextureData)::Bool
    extension = lowercase(splitext(path)[2])
    if extension == ".hdr"
        #todo fix wrong values
        #         bytes = Vector{UInt8}(undef, filesize(path))
        #         read!(path, bytes)
        img = load(path)
        texture.height, texture.width = size(img)
        texture.linear = true
        texture.pixelsf = Vector{Vec4f}(undef, length(img))
        for i in 1:length(img)
            texture.pixelsf[i] = Vec4f(img[i])
        end
        #         @printf(
        #             "%d %d\n%.5f %.5f %.5f %.5f\n%.5f %.5f %.5f %.5f\n",
        #             texture.width,
        #             texture.height,
        #             texture.pixelsf[1][1],
        #             texture.pixelsf[1][2],
        #             texture.pixelsf[1][3],
        #             texture.pixelsf[1][4],
        #             last(texture.pixelsf)[1],
        #             last(texture.pixelsf)[2],
        #             last(texture.pixelsf)[3],
        #             last(texture.pixelsf)[4],
        #         )
    elseif extension == ".png"
        bytes = Vector{UInt8}(undef, filesize(path))
        read!(path, bytes)
        img = load_(bytes)
        texture.height, texture.width = size(img)
        texture.linear = false
        texture.pixelsb = Vector{Vec4b}(undef, length(img))
        for i in 1:length(img)
            texture.pixelsb[i] = Vec4b(img[i])
        end
    else
        println("unknown texture format: ", extension)
        return false
    end
    true
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
    quadspos         :: Vector{Vec4i}
    quadsnorm        :: Vector{Vec4i}
    quadstexcoord    :: Vector{Vec4i}
    positions        :: Vector{Vec3f}
    normals          :: Vector{Vec3f}
    texcoords        :: Vector{Vec3f}
    subdivisions     :: Int32
    catmullclark     :: Bool
    smooth           :: Bool
    displacement     :: Float32
    displacement_tex :: Int32
    shape            :: Int32
end

struct SceneData
    cameras      :: Vector{CameraData}
    instances    :: Vector{InstanceData}
    environments :: Vector{EnvironmentData}
    shapes       :: Vector{ShapeData}
    textures     :: Vector{TextureData}
    materials    :: Vector{MaterialData}
    subdivs      :: Vector{SubdivData}
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

function eval_camera(camera::CameraData, image_uv::Vec2f, lens_uv::Vec2f)::Ray3f
    film = if camera.aspect >= 1
        Vec2f(camera.film, camera.film / camera.aspect)
    else
        Vec2f(camera.film * camera.aspect, camera.film)
    end
    if !camera.orthographic
        q = Vec3f(film[1] * (0.5 - image_uv[1]), film[2] * (image_uv[2] - 0.5), camera.lens)
        #ray direction through the lens center
        dc = -normalize(q)
        #point on the lens
        e = Vec3f(lens_uv[1] * camera.aperture / 2, lens_uv[2] * camera.aperture / 2, 0)
        #point on the focus plane
        p = dc * camera.focus / abs(dc[3])
        #correct ray direction to account for camera focusing
        d = normalize(p - e)
        #done
        Ray3f(transform_point(camera.frame, e), transform_direction(camera.frame, d))
    else
        scale = 1 / camera.lens
        q = Vec3f(
            film[1] * (0.5 - image_uv[1]) * scale,
            film[2] * (image_uv[2] - 0.5) * scale,
            camera.lens,
        )
        #point on the lens
        e =
            Vec3f(-q[1], -q[2], 0) +
            Vec3f(lens_uv[1] * camera.aperture / 2, lens_uv[2] * camera.aperture / 2, 0)
        #point on the focus plane
        p = Vec3f(-q[1], -q[2], -camera.focus)
        #correct ray direction to account for camera focusing
        d = normalize(p - e)
        #done
        Ray3f(transform_point(camera.frame, e), transform_direction(camera.frame, d))
    end
end

function add_sky(scene) end

end
