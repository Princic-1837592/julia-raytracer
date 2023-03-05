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
    transform_direction,
    cross,
    dot,
    transform_normal
using ..Shape: ShapeData
using ..Geometry:
    Ray3f,
    quad_normal,
    triangle_normal,
    interpolate_quad,
    interpolate_triangle,
    interpolate_line
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

struct MaterialPoint
    type         :: MaterialType
    emission     :: Vec3f
    color        :: Vec3f
    opacity      :: Float32
    roughness    :: Float32
    metallic     :: Float32
    ior          :: Float32
    density      :: Vec3f
    scattering   :: Vec3f
    scanisotropy :: Float32
    trdepth      :: Float32

    MaterialPoint() = new(gltfpbr, Vec3f(), Vec3f(), 1, 0, 0, 1, Vec3f(), Vec3f(), 0, 0.01)
    MaterialPoint(emission::Vec3f, color::Vec3f) =
        new(gltfpbr, emission, color, 1, 0, 0, 1, Vec3f(), Vec3f(), 0, 0.01)
    MaterialPoint(
        type::MaterialType,
        emission::Vec3f,
        color::Vec3f,
        opacity::Float32,
        roughness::Float32,
        metallic::Float32,
        ior::Float32,
        density::Vec3f,
        scattering::Vec3f,
        scanisotropy::Float32,
        trdepth::Float32,
    ) = new(
        type,
        emission,
        color,
        opacity,
        roughness,
        metallic,
        ior,
        density,
        scattering,
        scanisotropy,
        trdepth,
    )
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

function eval_shading_position(
    scene::SceneData,
    instance::InstanceData,
    element::Int32,
    uv::Vec2f,
    outgoing::Vec3f,
)::Vec3f
    shape = scene.shapes[instance.shape]
    if (length(shape.triangles) != 0 || length(shape.quads) != 0)
        return eval_position(scene, instance, element, uv)
    elseif (length(shape.lines))
        return eval_position(scene, instance, element, uv)
    elseif (length(shape.points))
        return eval_position(shape, element, uv)
    else
        return Vec3f(0, 0, 0)
    end
end

function eval_position(
    scene::SceneData,
    instance::InstanceData,
    element::Int32,
    uv::Vec2f,
)::Vec3f
    shape = scene.shapes[instance.shape]
    if (length(shape.triangles) != 0)
        t = shape.triangles[element]
        return transform_point(
            instance.frame,
            interpolate_triangle(
                shape.positions[t[1]],
                shape.positions[t[2]],
                shape.positions[t[3]],
                uv,
            ),
        )
    elseif (length(shape.quads) != 0)
        q = shape.quads[element]
        return transform_point(
            instance.frame,
            interpolate_quad(
                shape.positions[q[1]],
                shape.positions[q[2]],
                shape.positions[q[3]],
                shape.positions[q[4]],
                uv,
            ),
        )
    elseif (length(shape.lines) != 0)
        l = shape.lines[element]
        return transform_point(
            instance.frame,
            interpolate_line(shape.positions[l[1]], shape.positions[l[2]], uv[1]),
        )
    elseif (length(shape.points) != 0)
        return transform_point(instance.frame, shape.positions[shape.points[element]])
    else
        return Vec3f(0, 0, 0)
    end
end

function eval_shading_normal(
    scene::SceneData,
    instance::InstanceData,
    element::Int32,
    uv::Vec2f,
    outgoing::Vec3f,
)::Vec3f
    shape = scene.shapes[instance.shape]
    material = scene.materials[instance.material]
    if length(shape.triangles) != 0 || length(shape.quads) != 0
        normal = eval_normal(scene, instance, element, uv)
        if material.normal_tex != invalid_id
            normal = eval_normalmap(scene, instance, element, uv)
        end
        if material.type == refractive
            return normal
        end
        return if dot(normal, outgoing) >= 0
            normal
        else
            -normal
        end
    elseif length(shape.lines) != 0
        normal = eval_normal(scene, instance, element, uv)
        return orthonormalize(outgoing, normal)
    elseif length(shape.points) != 0
        return outgoing
    else
        return Vec3f(0, 0, 0)
    end
end

function eval_normal(
    scene::SceneData,
    instance::InstanceData,
    element::Int32,
    uv::Vec2f,
)::Vec3f
    shape = scene.shapes[instance.shape]
    if length(shape.normals) != 0
        return eval_element_normal(scene, instance, element)
    end
    if length(shape.triangles) != 0
        t = shape.triangles[element]
        return transform_normal(
            instance.frame,
            normalize(
                interpolate_triangle(
                    shape.normals[t[1]],
                    shape.normals[t[2]],
                    shape.normals[t[3]],
                    uv,
                ),
            ),
        )
    elseif length(shape.quads) != 0
        q = shape.quads[element]
        return transform_normal(
            instance.frame,
            normalize(
                interpolate_quad(
                    shape.normals[q[1]],
                    shape.normals[q[2]],
                    shape.normals[q[3]],
                    shape.normals[q[4]],
                    uv,
                ),
            ),
        )
    elseif length(shape.lines) != 0
        l = shape.lines[element]
        return transform_normal(
            instance.frame,
            normalize(interpolate_line(shape.normals[l[1]], shape.normals[l[2]], uv[1])),
        )
    elseif length(shape.points) != 0
        return transform_normal(
            instance.frame,
            normalize(shape.normals[shape.points[element]]),
        )
    else
        return Vec3f(0, 0, 0)
    end
end

function eval_element_normal(
    scene::SceneData,
    instance::InstanceData,
    element::Int32,
)::Vec3f
    shape = scene.shapes[instance.shape]
    if length(shape.triangles) != 0
        t = shape.triangles[element]
        return transform_normal(
            instance.frame,
            triangle_normal(
                shape.positions[t[1]],
                shape.positions[t[2]],
                shape.positions[t[3]],
            ),
        )
    elseif length(shape.quads) != 0
        q = shape.quads[element]
        return transform_normal(
            instance.frame,
            quad_normal(
                shape.positions[q[1]],
                shape.positions[q[2]],
                shape.positions[q[3]],
                shape.positions[q[4]],
            ),
        )
    elseif length(shape.lines) != 0
        l = shape.lines[element]
        return transform_normal(
            instance.frame,
            line_tangent(shape.positions[l[1]], shape.positions[l[2]]),
        )
    elseif length(shape.points) != 0
        return Vec3f(0, 0, 1)
    else
        return Vec3f(0, 0, 0)
    end
end

#yocto_scene.cpp 521
function eval_material(scene::SceneData, instance::InstanceData, element::Int32, uv::Vec2f)
    #todo
    MaterialPoint(Vec3f(1, 1, 1), Vec3f(1, 1, 1))
end

function eval_normalmap(
    scene::SceneData,
    instance::InstanceData,
    element::Int32,
    uv::Vec2f,
)::Vec3f
    shape = scene.shapes[instance.shape]
    material = scene.materials[instance.material]
    normal = eval_normal(scene, instance, element, uv)
    texcoord = eval_texcoord(scene, instance, element, uv)
    if material.normal_tex != invalid_id &&
       (length(shape.triangles) != 0 || length(shape.quads) != 0)
        normal_tex = scene.textures[material.normal_tex]
        normalmap = -1 + 2 * xyz(eval_texture(normal_tex, texcoord, false))
        (tu, tv) = eval_element_tangents(scene, instance, element)
        frame = Frame3f(tu, tv, normal, Vec3f(0, 0, 0))
        frame[1] = orthonormalize(frame[1], frame[3])
        frame[2] = normalize(cross(frame[3], frame[1]))
        flip_v = dot(frame[2], tv) < 0
        normalmap[2] *= if flip_v
            1
        else
            -1
        end
        normal = transform_normal(frame, normalmap)
    end
    normal
end

function eval_texcoord(
    scene::SceneData,
    instance::InstanceData,
    element::Int32,
    uv::Vec2f,
)::Vec2f
    shape = scene.shapes[instance.shape]
    if (length(shape.texcoords) == 0)
        return uv
    end
    if (length(shape.triangles) != 0)
        t = shape.triangles[element]
        interpolate_triangle(
            shape.texcoords[t[1]],
            shape.texcoords[t[2]],
            shape.texcoords[t[3]],
            uv,
        )
    elseif (length(shape.quads) != 0)
        q = shape.quads[element]
        interpolate_quad(
            shape.texcoords[q[1]],
            shape.texcoords[q[2]],
            shape.texcoords[q[3]],
            shape.texcoords[q[4]],
            uv,
        )
    elseif (length(shape.lines) != 0)
        l = shape.lines[element]
        interpolate_line(shape.texcoords[l[1]], shape.texcoords[l[2]], uv[1])
    elseif (length(shape.points) != 0)
        shape.texcoords[shape.points[element]]
    else
        vec2f{0,0}
    end
end

end
