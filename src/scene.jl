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
    Vec2i,
    normalize,
    transform_point,
    transform_direction,
    cross,
    dot,
    transform_normal,
    orthonormalize,
    inverse,
    pif
using ..Color: byte_to_float, srgb_to_rgb
using ..Shape: ShapeData
using ..Geometry:
    Ray3f,
    quad_normal,
    triangle_normal,
    interpolate_quad,
    interpolate_triangle,
    interpolate_line,
    triangle_tangents_fromuv,
    quad_tangents_fromuv
using ImageMagick: load, load_
using Printf: @printf

const invalid_id = -1
const min_roughness = 0.03f0 * 0.03f0

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
    shape    :: Int
    material :: Int

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
    emission_tex :: Int

    function EnvironmentData(json)
        frame = Frame3f(Float32.(get(json, "frame", Vector{Float32}(undef, 0))))
        emission = get(json, "emission", Vec3f())
        emission_tex = get(json, "emission_tex", invalid_id - 1) + 1
        #todo lookat
        new(frame, emission, emission_tex)
    end
end

struct TextureData
    width   :: Int
    height  :: Int
    linear  :: Bool
    pixelsf :: Vector{Vec4f}
    pixelsb :: Vector{Vec4b}

    TextureData() = new(0, 0, false, Vector{Vec4f}(undef, 0), Vector{Vec4b}(undef, 0))

    TextureData(
        width::Int,
        height::Int,
        linear::Bool,
        pixelsf::Vector{Vec4f},
        pixelsb::Vector{Vec4b},
    ) = new(width, height, linear, pixelsf, pixelsb)
end

function load_texture(path::String)::TextureData
    ext = lowercase(splitext(path)[2])
    if ext == ".hdr"
        #todo fix wrong values
        img = load(path)
        height, width = size(img)
        linear = true
        pixelsf = Vector{Vec4f}(undef, length(img))
        pixelsb = Vector{Vec4b}(undef, 0)
        for i in 1:length(img)
            pixelsf[i] = Vec4f(img[i])
        end
        #         for i in 1:500:length(texture.pixelsf)
        #             @printf(
        #                 "%d %.5f %.5f %.5f %.5f ",
        #                 i,
        #                 texture.pixelsf[i][1],
        #                 texture.pixelsf[i][2],
        #                 texture.pixelsf[i][3],
        #                 texture.pixelsf[i][4]
        #             )
        #             @printf(
        #                 "%d %.5f %.5f %.5f %.5f ",
        #                 i + 1,
        #                 texture.pixelsf[i + 1][1],
        #                 texture.pixelsf[i + 1][2],
        #                 texture.pixelsf[i + 1][3],
        #                 texture.pixelsf[i + 1][4]
        #             )
        #             @printf(
        #                 "%d %.5f %.5f %.5f %.5f\n",
        #                 i + 2,
        #                 texture.pixelsf[i + 2][1],
        #                 texture.pixelsf[i + 2][2],
        #                 texture.pixelsf[i + 2][3],
        #                 texture.pixelsf[i + 2][4]
        #             )
        #         end
    elseif ext == ".png"
        img = load(path)
        height, width = size(img)
        linear = false
        pixelsb = Vector{Vec4b}(undef, length(img))
        pixelsf = Vector{Vec4f}(undef, 0)
        for i in 1:length(img)
            pixelsb[i] = Vec4b(img[div((i - 1), width) + 1, ((i - 1) % width) + 1])
        end
    else
        error("unknown texture format: $ext")
    end
    TextureData(width, height, linear, pixelsf, pixelsb)
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
    emission_tex   :: Int
    color_tex      :: Int
    roughness_tex  :: Int
    scattering_tex :: Int
    normal_tex     :: Int

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
    subdivisions     :: Int
    catmullclark     :: Bool
    smooth           :: Bool
    displacement     :: Float32
    displacement_tex :: Int
    shape            :: Int
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

function find_camera(scene::SceneData, name::String)::Int
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
    film =
        camera.aspect >= 1 ? Vec2f(camera.film, camera.film / camera.aspect) :
        Vec2f(camera.film * camera.aspect, camera.film)

    if !camera.orthographic
        q = Vec3f(
            film[1] * (0.5f0 - image_uv[1]),
            film[2] * (image_uv[2] - 0.5f0),
            camera.lens,
        )
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
            film[1] * (0.5f0 - image_uv[1]) * scale,
            film[2] * (image_uv[2] - 0.5f0) * scale,
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

#confirmed correct
function eval_shading_position(
    scene::SceneData,
    instance::InstanceData,
    element::Int,
    uv::Vec2f,
    outgoing::Vec3f,
)::Vec3f
    shape = scene.shapes[instance.shape]
    if (length(shape.triangles) != 0 || length(shape.quads) != 0)
        return eval_position(scene, instance, element, uv)
    elseif (length(shape.lines) != 0)
        return eval_position(scene, instance, element, uv)
    elseif (length(shape.points) != 0)
        return eval_position(shape, element, uv)
    else
        return Vec3f(0, 0, 0)
    end
end

function eval_position(
    scene::SceneData,
    instance::InstanceData,
    element::Int,
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

#confirmed correct
function eval_shading_normal(
    scene::SceneData,
    instance::InstanceData,
    element::Int,
    uv::Vec2f,
    outgoing::Vec3f,
)::Vec3f
    #     @printf(
    #         "element: %d uv: %.5f %.5f outgoing: %.5f %.5f %.5f\n",
    #         element,
    #         uv[1],
    #         uv[2],
    #         outgoing[1],
    #         outgoing[2],
    #         outgoing[3]
    #     )
    shape = scene.shapes[instance.shape]
    material = scene.materials[instance.material]
    if length(shape.triangles) != 0 || length(shape.quads) != 0
        normal = eval_normal(scene, instance, element, uv)
        #         @printf("normal: %.5f %.5f %.5f\n", normal[1], normal[2], normal[3])
        if material.normal_tex != invalid_id
            #             println("eval_normalmap")
            normal = eval_normalmap(scene, instance, element, uv)
        end
        if material.type == refractive
            #             println("refractive")
            return normal
        end
        normal = if dot(normal, outgoing) >= 0
            normal
        else
            -normal
        end
        #         @printf("normal after dot: %.5f %.5f %.5f\n", normal[1], normal[2], normal[3])
        normal
    elseif length(shape.lines) != 0
        normal = eval_normal(scene, instance, element, uv)
        orthonormalize(outgoing, normal)
    elseif length(shape.points) != 0
        outgoing
    else
        Vec3f(0, 0, 0)
    end
end

function eval_normal(
    scene::SceneData,
    instance::InstanceData,
    element::Int,
    uv::Vec2f,
)::Vec3f
    shape = scene.shapes[instance.shape]
    if length(shape.normals) == 0
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

function eval_element_normal(scene::SceneData, instance::InstanceData, element::Int)::Vec3f
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

#confirmed correct
function eval_material(
    scene::SceneData,
    instance::InstanceData,
    element::Int,
    uv::Vec2f,
)::MaterialPoint
    material = scene.materials[instance.material]
    texcoord = eval_texcoord(scene, instance, element, uv)

    emission_tex = eval_texture(scene, material.emission_tex, texcoord, true)
    color_shp = eval_color(scene, instance, element, uv)
    color_tex = eval_texture(scene, material.color_tex, texcoord, true)
    roughness_tex = eval_texture(scene, material.roughness_tex, texcoord, false)
    scattering_tex = eval_texture(scene, material.scattering_tex, texcoord, true)

    type = material.type
    emission = material.emission .* Vec3f(emission_tex)
    color = material.color .* Vec3f(color_tex) .* Vec3f(color_shp)
    opacity = material.opacity * color_tex.w * color_shp.w
    metallic = material.metallic * roughness_tex.z
    roughness = material.roughness * roughness_tex.y
    roughness = roughness * roughness
    ior = material.ior
    scattering = material.scattering .* Vec3f(scattering_tex)
    scanisotropy = material.scanisotropy
    trdepth = material.trdepth

    if (
        material.type == refractive ||
        material.type == volumetric ||
        material.type == subsurface
    )
        density = -log.(clamp.(color, 0.0001f0, 1.0f0)) / trdepth
    else
        density = Vec3f(0, 0, 0)
    end

    if (type == matte || type == gltfpbr || type == glossy)
        roughness = clamp(roughness, min_roughness, 1.0f0)
    elseif (material.type == volumetric)
        roughness = 0.0f0
    elseif (roughness < min_roughness)
        roughness = 0.0f0
    end

    return MaterialPoint(
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

function eval_texture(
    scene::SceneData,
    texture::Int,
    uv::Vec2f,
    ldr_as_linear::Bool = false,
    no_interpolation::Bool = false,
    clamp_to_edge::Bool = false,
)::Vec4f
    if (texture == invalid_id)
        Vec4f(1, 1, 1, 1)
    else
        eval_texture(scene.textures[texture], uv, ldr_as_linear, no_interpolation)
    end
end

function eval_color(
    scene::SceneData,
    instance::InstanceData,
    element::Int,
    uv::Vec2f,
)::Vec4f
    shape = scene.shapes[instance.shape]
    if (length(shape.colors) == 0)
        return Vec4f(1, 1, 1, 1)
    end
    if (length(shape.triangles) != 0)
        t = shape.triangles[element]
        interpolate_triangle(shape.colors[t[1]], shape.colors[t[2]], shape.colors[t[3]], uv)
    elseif (length(shape.quads) != 0)
        q = shape.quads[element]
        interpolate_quad(
            shape.colors[q[1]],
            shape.colors[q[2]],
            shape.colors[q[3]],
            shape.colors[q[4]],
            uv,
        )
    elseif (length(shape.lines) != 0)
        l = shape.lines[element]
        interpolate_line(shape.colors[l[1]], shape.colors[l[2]], uv[1])
    elseif (length(shape.points) != 0)
        shape.colors[shape.points[element]]
    else
        Vec4f(0, 0, 0, 0)
    end
end

function eval_normalmap(
    scene::SceneData,
    instance::InstanceData,
    element::Int,
    uv::Vec2f,
)::Vec3f
    shape = scene.shapes[instance.shape]
    material = scene.materials[instance.material]
    normal = eval_normal(scene, instance, element, uv)
    texcoord = eval_texcoord(scene, instance, element, uv)
    if material.normal_tex != invalid_id &&
       (length(shape.triangles) != 0 || length(shape.quads) != 0)
        normal_tex = scene.textures[material.normal_tex]
        #todo check order of operations
        normalmap = Vec3f(eval_texture(normal_tex, texcoord, false)) .* 2 .- 1
        (tu, tv) = eval_element_tangents(scene, instance, element)
        frame = Frame3f(tu, tv, normal, Vec3f(0, 0, 0))
        f1 = orthonormalize(frame[1], frame[3])
        f2 = normalize(cross(frame[3], frame[1]))
        frame = Frame3f(f1, f2, frame[3], frame[4])
        flip_v = dot(frame[2], tv) < 0
        n2 = normalmap[2] * if flip_v
            1
        else
            -1
        end
        normalmap = Vec3f(normalmap[1], n2, normalmap[3])
        normal = transform_normal(frame, normalmap)
    end
    normal
end

function eval_texcoord(
    scene::SceneData,
    instance::InstanceData,
    element::Int,
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
        Vec2f(0, 0)
    end
end

function eval_texture(
    texture::TextureData,
    uv::Vec2f,
    as_linear::Bool,
    no_interpolation::Bool = false,
    clamp_to_edge::Bool = false,
)::Vec4f
    if (texture.width == 0 || texture.height == 0)
        return Vec4f(0, 0, 0, 0)
    end

    size = Vec2i(texture.width, texture.height)

    s = 0.0f0
    t = 0.0f0
    if (clamp_to_edge)
        s = clamp(uv[1], 0.0f0, 1.0f0) * size[1]
        t = clamp(uv[2], 0.0f0, 1.0f0) * size[2]
    else
        #todo check fmod
        s = mod1(uv[1], 1.0f0) * size[1]
        if (s < 0)
            s += size[1]
        end
        t = mod1(uv[2], 1.0f0) * size[2]
        if (t < 0)
            t += size[2]
        end
    end

    i = clamp(trunc(Int, s), 0, size[1] - 1)
    j = clamp(trunc(Int, t), 0, size[2] - 1)
    ii = (i + 1) % size[1]
    jj = (j + 1) % size[2]
    u = s - i
    v = t - j

    if (no_interpolation)
        lookup_texture(texture, i, j, as_linear)
    else
        lookup_texture(texture, i, j, as_linear) * (1 - u) * (1 - v) +
        lookup_texture(texture, i, jj, as_linear) * (1 - u) * v +
        lookup_texture(texture, ii, j, as_linear) * u * (1 - v) +
        lookup_texture(texture, ii, jj, as_linear) * u * v
    end
end

function lookup_texture(
    texture::TextureData,
    i::Int,
    j::Int,
    as_linear::Bool = false,
)::Vec4f
    color = Vec4f(0, 0, 0, 0)
    if (length(texture.pixelsf) != 0)
        color = texture.pixelsf[j * texture.width + i + 1]
    else
        color = byte_to_float(texture.pixelsb[j * texture.width + i + 1])
    end
    if (as_linear && !texture.linear)
        srgb_to_rgb(color)
    else
        color
    end
end

function eval_element_tangents(
    scene::SceneData,
    instance::InstanceData,
    element::Int,
)::Tuple{Vec3f,Vec3f}
    shape = scene.shapes[instance.shape]
    if (length(shape.triangles) != 0 && length(shape.texcoords) != 0)
        t = shape.triangles[element]
        (tu, tv) = triangle_tangents_fromuv(
            shape.positions[t[1]],
            shape.positions[t[2]],
            shape.positions[t[3]],
            shape.texcoords[t[1]],
            shape.texcoords[t[2]],
            shape.texcoords[t[3]],
        )
        return (
            transform_direction(instance.frame, tu),
            transform_direction(instance.frame, tv),
        )
    elseif (length(shape.quads) != 0 && length(shape.texcoords) != 0)
        q = shape.quads[element]
        (tu, tv) = quad_tangents_fromuv(
            shape.positions[q[1]],
            shape.positions[q[2]],
            shape.positions[q[3]],
            shape.positions[q[4]],
            shape.texcoords[q[1]],
            shape.texcoords[q[2]],
            shape.texcoords[q[3]],
            shape.texcoords[q[4]],
            Vec2f(0, 0),
        )
        return (
            transform_direction(instance.frame, tu),
            transform_direction(instance.frame, tv),
        )
    else
        return (Vec3f(), Vec3f())
    end
end

function eval_environment(scene::SceneData, direction::Vec3f)::Vec3f
    emission = Vec3f(0, 0, 0)
    for environment in scene.environments
        emission = emission .+ eval_environment(scene, environment, direction)
    end
    emission
end

function eval_environment(
    scene::SceneData,
    environment::EnvironmentData,
    direction::Vec3f,
)::Vec3f
    wl = transform_direction(inverse(environment.frame), direction)
    texcoord =
        Vec2f(atan(wl[3], wl[1]) / (2.0f0 * pif), acos(clamp(wl[2], -1.0f0, 1.0f0)) / pif)
    if (texcoord[1] < 0.0f0)
        texcoord1 = texcoord[1] + 1.0f0
        texcoord = Vec2f(texcoord1, texcoord[2])
    end
    environment.emission .* Vec3f(eval_texture(scene, environment.emission_tex, texcoord))
end

is_delta(material::MaterialPoint)::Bool =
    (material.type == reflective && material.roughness == 0) ||
    (material.type == refractive && material.roughness == 0) ||
    (material.type == transparent && material.roughness == 0) ||
    (material.type == volumetric)

is_volumetric(scene::SceneData, instance::InstanceData)::Bool =
    is_volumetric(scene.materials[instance.material])

is_volumetric(material::MaterialData)::Bool =
    material.type == refractive ||
    material.type == volumetric ||
    material.type == subsurface

end
