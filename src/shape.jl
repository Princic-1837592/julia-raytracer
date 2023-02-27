#=
shape:
- Julia version: 
- Author: Andrea
- Date: 2023-01-03
=#

module Shape

using PlyIO: load_ply
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
        #         dump(ply)
        positions = get_positions(ply)
        dump(positions[1])
        dump(positions[length(positions)])
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

    function get_positions(ply)
        element = ply["vertex"]
        properties = ["x", "y", "z"]
        x = nothing
        y = nothing
        z = nothing
        for property in element.properties
            if property.name == "x"
                x = property
            elseif property.name == "y"
                y = property
            elseif property.name == "z"
                z = property
            end
        end
        if x == nothing || y == nothing || z == nothing
            error("missing properties")
        end
        positions = Array{Vec3f,1}(undef, length(x.data))
        for i in 1:length(x.data)
            positions[i] = Vec3f(x.data[i], y.data[i], z.data[i])
        end
        return positions
    end
end

end
