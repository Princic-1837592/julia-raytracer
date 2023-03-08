#=
image:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-03-02
=#

module Image

using ..Math: Vec4f, Vec4b
using ..Color: float_to_byte, rgb_to_srgb

mutable struct ImageData
    width  :: Int
    height :: Int
    pixels :: Vector{Vec4f}
    linear :: Bool

    ImageData(width, height, data, linear) = new(width, height, data, linear)
end

function make_image(width::Int, height::Int, linear::Bool)::ImageData
    image = Vector{Vec4f}(undef, width * height)
    fill!(image, Vec4f(0, 0, 0, 0))
    ImageData(width, height, image, linear)
end

function image_rgb_to_srgb(srgb::Vector{Vec4f}, rgb::Vector{Vec4f})
    resize!(srgb, length(rgb))
    for i in 1:length(rgb)
        srgb[i] = rgb_to_srgb(rgb[i])
    end
end

end
