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
    points    :: Array{Int32,1}
    lines     :: Array{Vec2i,1}
    triangles :: Array{Vec3i,1}
    quads     :: Array{Vec4i,1}
    positions :: Array{Vec3f,1}
    normals   :: Array{Vec3f,1}
    texcoords :: Array{Vec2f,1}
    colors    :: Array{Vec4f,1}
    radius    :: Array{Float32,1}
    tangents  :: Array{Vec4f,1}

    ShapeData() = new()
end

function load_shape(path::String, shape::ShapeData)::Bool
    println("$path")
    if splitext(path)[2] != ".ply"
        error("only ply files are supported")
    end
    ply = load_ply(path)
    shape.positions = Array{Vec3f,1}(undef, 0)
    result = get_vec3f_array(ply, "vertex", ["x", "y", "z"], shape.positions)
    shape.normals = Array{Vec3f,1}(undef, 0)
    result = get_vec3f_array(ply, "vertex", ["nx", "ny", "nz"], shape.normals)
    shape.texcoords = Array{Vec2f,1}(undef, 0)
    result = get_tex_coords(ply, true, shape.texcoords)
    #todo check in case there are more than 0
    shape.colors = Array{Vec4f,1}(undef, 0)
    result = get_colors(ply, shape.colors)
    shape.radius = Array{Float32,1}(undef, 0)
    result = get_f_array(ply, "vertex", "radius", shape.radius)
    shape.triangles = Array{Vec3i,1}(undef, 0)
    shape.quads = Array{Vec4i,1}(undef, 0)
    result = get_faces(ply, "face", "vertex_indices", shape.triangles, shape.quads)
    shape.lines = Array{Vec2i,1}(undef, 0)
    result = get_lines(ply, "line", "vertex_indices", shape.lines)
    shape.points = Array{Int32,1}(undef, 0)
    result = get_list_values(ply, "point", "vertex_indices", shape.points)

    return !(
        length(shape.points) == 0 &&
        length(shape.lines) == 0 &&
        length(shape.triangles) == 0 &&
        length(shape.quads) == 0
    )
end

function get_vec4f_array(
    ply::Ply,
    s_element::String,
    s_properties::Array{String,1},
    array::Array{Vec4f,1},
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
    s_properties::Array{String,1},
    array::Array{Vec3f,1},
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
    s_properties::Array{String,1},
    flip::Bool,
    array::Array{Vec2f,1},
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
    array::Array{Float32,1},
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

function get_tex_coords(ply::Ply, flip::Bool, array::Array{Vec2f,1})::Bool
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

function get_colors(ply::Ply, array::Array{Vec4f,1})::Bool
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
    partial = Array{Vec3f,1}(undef, 0)
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

function get_vec4i_array(property::ListProperty, quads::Array{Vec4i,1})::Bool
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
    triangles::Array{Vec3i,1},
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

function get_vec2i_array(property::ListProperty, lines::Array{Vec2i,1})::Bool
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

#TODO IMPORTANT maybe indexes in quads and triangles are to be incremented by 1 since this is julia
function get_faces(
    ply::Ply,
    element::String,
    property::String,
    triangles::Array{Vec3i,1},
    quads::Array{Vec4i,1},
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
    lines::Array{Vec2i,1},
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
    values::Array{Int32,1},
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
