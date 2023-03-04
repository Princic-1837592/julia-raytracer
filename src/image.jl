#=
image:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-03-02
=#

module Image

using ..Math: Vec4f

mutable struct ImageData
    width  :: Int
    height :: Int
    data   :: Vector{Vec4f}
    linear :: Bool

    ImageData(width, height, data, linear) = new(width, height, data, linear)
end

function make_image(width::Int32, height::Int32, linear::Bool)::ImageData
    image = Vector{Vec4f}(undef, width * height)
    fill!(image, Vec4f(0, 0, 0, 0))
    ImageData(width, height, image, linear)
end

end
