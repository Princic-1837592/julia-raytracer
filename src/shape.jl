#=
shape:
- Julia version: 
- Author: Andrea
- Date: 2023-01-03
=#

module Shape

using PlyIO: load_ply, ArrayProperty, ListProperty, Ply
using ..Math: Vec2i, Vec3f, Vec4f, Vec3i, Vec4i, Vec2f

mutable struct ShapeData
    points    :: Vector{Int32}
    lines     :: Vector{Vec2i}
    triangles :: Vector{Vec3i}
    quads     :: Vector{Vec4i}
    positions :: Vector{Vec3f}
    normals   :: Vector{Vec3f}
    texcoords :: Vector{Vec2f}
    colors    :: Vector{Vec4f}
    radius    :: Vector{Float32}
    tangents  :: Vector{Vec4f}

    ShapeData() = new()
end

struct ShapeIntersection
    element  :: Int32
    uv       :: Vec2f
    distance :: Float32
    hit      :: Bool

    ShapeIntersection() = new(-1, Vec2f(0.0, 0.0), 0.0, false)
    ShapeIntersection(element::Int32, uv::Vec2f, distance::Float32, hit::Bool) =
        new(element, uv, distance, hit)
end

function load_shape(path::String, shape::ShapeData)::Bool
    if lowercase(splitext(path)[2]) != ".ply"
        return false
    end
    ply = load_ply(path)
    shape.positions = Vector{Vec3f}(undef, 0)
    result = get_vec3f_array(ply, "vertex", ["x", "y", "z"], shape.positions)
    shape.normals = Vector{Vec3f}(undef, 0)
    result = get_vec3f_array(ply, "vertex", ["nx", "ny", "nz"], shape.normals)
    shape.texcoords = Vector{Vec2f}(undef, 0)
    result = get_tex_coords(ply, true, shape.texcoords)
    #todo check in case there are more than 0
    shape.colors = Vector{Vec4f}(undef, 0)
    result = get_colors(ply, shape.colors)
    shape.radius = Vector{Float32}(undef, 0)
    result = get_f_array(ply, "vertex", "radius", shape.radius)
    shape.triangles = Vector{Vec3i}(undef, 0)
    shape.quads = Vector{Vec4i}(undef, 0)
    result = get_faces(ply, "face", "vertex_indices", shape.triangles, shape.quads)
    shape.lines = Vector{Vec2i}(undef, 0)
    result = get_lines(ply, "line", "vertex_indices", shape.lines)
    shape.points = Vector{Int32}(undef, 0)
    result = get_list_values(ply, "point", "vertex_indices", shape.points)
    #todo-check if correct. used to index @bvh:78, maybe increasing is needed here
    for collection in [shape.points, shape.lines, shape.triangles, shape.quads]
        for i in 1:length(collection)
            collection[i] = collection[i] .+ 1
        end
    end

    return length(shape.points) != 0 ||
           length(shape.lines) != 0 ||
           length(shape.triangles) != 0 ||
           length(shape.quads) != 0
end

function get_vec4f_array(
    ply::Ply,
    s_element::String,
    s_properties::Vector{String},
    array::Vector{Vec4f},
)::Bool
    element = try
        ply[s_element]
    catch e
        return false
    end
    properties = Vector{ArrayProperty{Float32,String}}(undef, 4)
    exists = [false, false, false, false]
    for property in element.properties
        if property.name == s_properties[1]
            exists[1] = true
            properties[1] = property
        elseif property.name == s_properties[2]
            exists[2] = true
            properties[2] = property
        elseif property.name == s_properties[3]
            exists[3] = true
            properties[3] = property
        elseif property.name == s_properties[4]
            exists[4] = true
            properties[4] = property
        end
    end
    if !all(exists) || any(map(p -> (p isa ListProperty), properties))
        return false
    end
    resize!(array, length(properties[1].data))
    for i in 1:length(properties[1].data)
        array[i] = Vec4f(
            properties[1].data[i],
            properties[2].data[i],
            properties[3].data[i],
            properties[4].data[i],
        )
    end
    return true
end

function get_vec3f_array(
    ply::Ply,
    s_element::String,
    s_properties::Vector{String},
    array::Vector{Vec3f},
)::Bool
    element = try
        ply[s_element]
    catch e
        return false
    end
    properties = Vector{ArrayProperty{Float32,String}}(undef, 3)
    exists = [false, false, false]
    for property in element.properties
        if property.name == s_properties[1]
            exists[1] = true
            properties[1] = property
        elseif property.name == s_properties[2]
            exists[2] = true
            properties[2] = property
        elseif property.name == s_properties[3]
            exists[3] = true
            properties[3] = property
        end
    end
    if !all(exists) || any(map(p -> (p isa ListProperty), properties))
        return false
    end
    resize!(array, length(properties[1].data))
    for i in 1:length(properties[1].data)
        array[i] =
            Vec3f(properties[1].data[i], properties[2].data[i], properties[3].data[i])
    end
    return true
end

function get_vec2f_array(
    ply::Ply,
    s_element::String,
    s_properties::Vector{String},
    flip::Bool,
    array::Vector{Vec2f},
)::Bool
    element = try
        ply[s_element]
    catch e
        return false
    end
    properties = Vector{ArrayProperty{Float32,String}}(undef, 2)
    exists = [false, false]
    for property in element.properties
        if property.name == s_properties[1]
            exists[1] = true
            properties[1] = property
        elseif property.name == s_properties[2]
            exists[2] = true
            properties[2] = property
        end
    end
    if !all(exists) || any(map(p -> (p isa ListProperty), properties))
        return false
    end
    resize!(array, length(properties[1].data))
    for i in 1:length(properties[1].data)
        array[i] = if flip
            Vec2f(properties[1].data[i], 1 - properties[2].data[i])
        else
            Vec2f(properties[1].data[i], properties[2].data[i])
        end
    end
    return true
end

function get_f_array(
    ply::Ply,
    s_element::String,
    s_property::String,
    array::Vector{Float32},
)::Bool
    element = try
        ply[s_element]
    catch e
        return false
    end
    for property in element.properties
        if property.name == s_property
            resize!(array, length(property.data))
            for i in 1:length(property.data)
                array[i] = property.data[i]
            end
            return true
        end
    end
    return false
end

function get_tex_coords(ply::Ply, flip::Bool, array::Vector{Vec2f})::Bool
    element = try
        ply["vertex"]
    catch e
        return false
    end
    for property in element.properties
        if property.name == "s"
            return get_vec2f_array(ply, "vertex", ["s", "t"], flip, array)
        else
            return get_vec2f_array(ply, "vertex", ["u", "v"], flip, array)
        end
    end
end

function get_colors(ply::Ply, array::Vector{Vec4f})::Bool
    element = try
        ply["vertex"]
    catch e
        return false
    end
    for property in element.properties
        if property.name == "alpha"
            return get_vec4f_array(ply, "vertex", ["red", "green", "blue", "alpha"], array)
        end
    end
    partial = Vector{Vec3f}(undef, 0)
    if !get_vec3f_array(ply, "vertex", ["red", "green", "blue"], partial)
        return false
    end
    resize!(array, length(properties[1].data))
    for i in 1:length(partial)
        array[i] = Vec4f(partial[i][1], partial[i][2], partial[i][3], 1)
    end
    return true
end

function has_quads(ply::Ply, s_element::String, s_property::String)::Bool
    element = try
        ply[s_element]
    catch e
        return false
    end
    for property in element.properties
        if property.name == s_property
            if !(property isa ListProperty)
                return false
            end
            for i in 2:length(property.start_inds)
                if property.start_inds[i] - property.start_inds[i - 1] == 4
                    return true
                end
            end
        end
    end
    return false
end

function get_vec4i_array(property::ListProperty, quads::Vector{Vec4i})::Bool
    sizehint!(quads, length(property.start_inds) - 1)
    for i in 1:(length(property.start_inds) - 1)
        index = property.start_inds[i]
        size = property.start_inds[i + 1] - index
        if size == 0
            push!(quads, Vec4i(-1, -1, -1, -1))
        elseif size == 1
            push!(quads, Vec4i(property.data[index], -1, -1, -1))
        elseif size == 2
            push!(quads, Vec4i(property.data[index], property.data[index + 1], -1, -1))
        elseif size == 3
            push!(
                quads,
                Vec4i(
                    property.data[index],
                    property.data[index + 1],
                    property.data[index + 2],
                    property.data[index + 2],
                ),
            )
        elseif size == 4
            push!(
                quads,
                Vec4i(
                    property.data[index],
                    property.data[index + 1],
                    property.data[index + 2],
                    property.data[index + 3],
                ),
            )
        else
            for item in 2:(size - 1)
                push!(
                    quads,
                    Vec4i(
                        property.data[index],
                        property.data[index + item - 1],
                        property.data[index + item],
                        property.data[index + item],
                    ),
                )
            end
        end
    end
    return true
end

function get_vec3i_array(
    property::ListProperty{UInt8,Int32},
    triangles::Vector{Vec3i},
)::Bool
    sizehint!(triangles, length(property.start_inds) - 1)
    for i in 1:(length(property.start_inds) - 1)
        index = property.start_inds[i]
        size = property.start_inds[i + 1] - index
        if size == 0
            push!(triangles, Vec3i(-1, -1, -1))
        elseif size == 1
            push!(triangles, Vec3i(property.data[index], -1, -1))
        elseif size == 2
            push!(triangles, Vec3i(property.data[index], property.data[index + 1], -1))
        elseif size == 3
            push!(
                triangles,
                Vec3i(
                    property.data[index],
                    property.data[index + 1],
                    property.data[index + 2],
                ),
            )
        else
            for item in 2:(size - 1)
                push!(
                    triangles,
                    Vec3i(
                        property.data[index],
                        property.data[index + item - 1],
                        property.data[index + item],
                    ),
                )
            end
        end
    end
    return true
end

function get_vec2i_array(property::ListProperty, lines::Vector{Vec2i})::Bool
    sizehint!(lines, length(property.start_inds) - 1)
    for i in 1:(length(property.start_inds) - 1)
        index = property.start_inds[i]
        size = property.start_inds[i + 1] - index
        if size == 0
            push!(lines, Vec2i(-1, -1))
        elseif size == 1
            push!(lines, Vec2i(property.data[index], -1))
        elseif size == 2
            push!(lines, Vec2i(property.data[index], property.data[index + 1]))
        else
            for item in 1:(size - 1)
                push!(
                    lines,
                    Vec2i(property.data[index + item - 1], property.data[index + item]),
                )
            end
        end
    end
    return true
end

function get_faces(
    ply::Ply,
    element::String,
    property::String,
    triangles::Vector{Vec3i},
    quads::Vector{Vec4i},
)::Bool
    if has_quads(ply, element, property)
        return get_vec4i_array(ply[element][property], quads)
    end
    return get_vec3i_array(ply[element][property], triangles)
end

function get_lines(
    ply::Ply,
    s_element::String,
    s_property::String,
    lines::Vector{Vec2i},
)::Bool
    element = try
        ply[s_element]
    catch e
        return false
    end
    for property in element.properties
        if property.name == s_property && property isa ListProperty
            return get_vec2i_array(property, lines)
        end
    end
    return false
end

function get_list_values(
    ply::Ply,
    s_element::String,
    s_property::String,
    values::Vector{Int32},
)::Bool
    element = try
        ply[s_element]
    catch e
        return false
    end
    for property in element.properties
        if property.name == s_property && property isa ListProperty
            resize!(values, length(property.data))
            copyto!(values, property.data)
            return true
        end
    end
    return false
end

end
