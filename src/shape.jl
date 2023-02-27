#=
shape:
- Julia version: 
- Author: Andrea
- Date: 2023-01-03
=#

module Shape

using ..Math: Vec2i, Vec3f, Vec4f, Vec3i, Vec4i, Vec2f

struct ShapeData
    points::Array{Int32,1}
    lines::Array{Vec2i,1}
    triangles::Array{Vec3i,1}
    quads::Array{Vec4i,1}

    positions::Array{Vec3f,1}
    normals::Array{Vec3f,1}
    texcoords::Array{Vec2f,1}
    colors::Array{Vec4f,1}
    radius::Array{Float32,1}
    tangents::Array{Vec4f,1}
end

end
