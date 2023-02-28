#=
shape:
- Julia version: 
- Author: Andrea
- Date: 2023-01-03
=#

module Shape

using PlyIO: load_ply, ArrayProperty, ListProperty
using ..Math: Vec2i, Vec3f, Vec4f, Vec3i, Vec4i, Vec2f

struct ShapeData
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
    function ShapeData(json, dir::String)
        #todo yocto_sceneio.cpp line 946
        filename = joinpath(dir, json["uri"])
        if splitext(filename)[2] != ".ply"
            error("only ply files are supported")
        end
        ply = load_ply(filename)
        positions = Array{Vec3f,1}(undef, 0)
        result = get_vec3f_array(ply, "vertex", ["x", "y", "z"], positions)
        #         println("$(json["uri"]) $result $(length(positions))")
        #         println("$(positions[1][1]) $(positions[1][2]) $(positions[1][3])")
        #         println(
        #             "$(positions[length(positions)][1]) $(positions[length(positions)][2]) $(positions[length(positions)][3])",
        #         )
        normals = Array{Vec3f,1}(undef, 0)
        result = get_vec3f_array(ply, "vertex", ["nx", "ny", "nz"], normals)
        #         println("$(json["uri"]) $result $(length(normals))")
        #         println("$(normals[1][1]) $(normals[1][2]) $(normals[1][3])")
        #         println(
        #             "$(normals[length(normals)][1]) $(normals[length(normals)][2]) $(normals[length(normals)][3])",
        #         )
        texcoords = Array{Vec2f,1}(undef, 0)
        result = get_tex_coords(ply, true, texcoords)
        #         println("$(json["uri"]) $result $(length(texcoords))")
        #         println("$(texcoords[1][1]) $(texcoords[1][2])")
        #         println("$(texcoords[length(texcoords)][1]) $(texcoords[length(texcoords)][2])")
        #todo check in case there are more than 0
        colors = Array{Vec4f,1}(undef, 0)
        result = get_colors(ply, colors)
        println("$(json["uri"]) $result $(length(colors))")
        #                 println("$(colors[1][1]) $(colors[1][2]) $(colors[1][3]) $(colors[1][4])")
        #                 println(
        #                     "$(colors[length(colors)][1]) $(colors[length(colors)][2]) $(colors[length(colors)][3]) $(colors[length(colors)][4])",
        #                 )
        #         #todo check in case there are more than 0
        #         (triangles, quads) = get_radius(ply)
        #         println(json["uri"], " ", length(triangles), " ", length(quads))
        #         println("$(json["uri"]) $(length(triangles)) $(length(quads))")
        #         if length(triangles) > 0
        #             dump(triangles[1])
        #             dump(triangles[length(triangles)])
        #         end
        #         if length(quads) > 0
        #             dump(quads[1])
        #             dump(quads[length(quads)])
        #         end
        #get_lines yocto_modelio.h line 713
        new(
            Array{Int32,1}(),
            Array{Vec2i,1}(),
            Array{Vec3i,1}(),
            Array{Vec4i,1}(),
            Array{Vec3f,1}(),
            Array{Vec3f,1}(),
            Array{Vec2f,1}(),
            Array{Vec4f,1}(),
            Array{Float32,1}(),
            Array{Vec4f,1}(),
        )
    end

    function get_vec4f_array(
        ply,
        s_element::String,
        s_properties::Array{String,1},
        array::Array{Vec4f,1},
    )::Bool
        element = ply[s_element]
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
        ply,
        s_element::String,
        s_properties::Array{String,1},
        array::Array{Vec3f,1},
    )::Bool
        element = ply[s_element]
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
        ply,
        s_element::String,
        s_properties::Array{String,1},
        flip::Bool,
        array::Array{Vec2f,1},
    )::Bool
        element = ply[s_element]
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

    function get_tex_coords(ply, flip::Bool, array::Array{Vec2f,1})::Bool
        for property in ply["vertex"].properties
            if property.name == "s"
                return get_vec2f_array(ply, "vertex", ["s", "t"], flip, array)
            else
                return get_vec2f_array(ply, "vertex", ["u", "v"], flip, array)
            end
        end
    end

    function get_colors(ply, array::Array{Vec4f,1})::Bool
        for property in ply["vertex"].properties
            if property.name == "alpha"
                return get_vec4f_array(
                    ply,
                    "vertex",
                    ["red", "green", "blue", "alpha"],
                    array,
                )
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

    function get_radius(ply)::Array{Float32,1}
        for property in ply["vertex"].properties
            if property.name == "radius"
                property = ply["vertex"]["radius"]
                if property isa ArrayProperty{Float32,String}
                    result = Array{Float32,1}(undef, length(property.data))
                    for i in 1:length(property.data)
                        result[i] = property.data[i]
                    end
                    return result
                end
            end
        end
        return Array{Float32,1}(undef, 0)
    end

    function get_faces(ply)::(Array{Vec3i,1}, Array{Vec4i,1})
        return (Array{Vec3i,1}(undef, 0), Array{Vec4i,1}(undef, 0))
    end
end

end
