#=
shape:
- Julia version: 
- Author: Andrea
- Date: 2023-01-03
=#

module Shape

using PlyIO: load_ply, ArrayProperty
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
        positions = get_vec3f_array(ply, "vertex", ["x", "y", "z"])
        normals = get_vec3f_array(ply, "vertex", ["nx", "ny", "nz"])
        #         dump(normals[1])
        #         dump(normals[length(normals)])
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

    function get_vec3f_array(
        ply,
        s_element::String,
        s_properties::Array{String,1},
    )::Array{Vec3f,1}
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
        if !all(exists)
            error("missing properties")
        end
        result = Array{Vec3f,1}(undef, length(properties[1].data))
        for i in 1:length(properties[1].data)
            result[i] =
                Vec3f(properties[1].data[i], properties[2].data[i], properties[3].data[i])
        end
        return result
    end
end

end
