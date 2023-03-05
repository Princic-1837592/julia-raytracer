#=
color:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-03-05
=#

module Color

using ..Math: Vec4b, Vec4f

byte_to_float(a::Vec4b)::Vec4f =
    Vec4f(a[1] / 255.0f0, a[2] / 255.0f0, a[3] / 255.0f0, a[4] / 255.0f0)

srgb_to_rgb(c::Vec4f)::Vec4f =
    Vec4f(srgb_to_rgb(c[1]), srgb_to_rgb(c[2]), srgb_to_rgb(c[3]), c[4])

srgb_to_rgb(c::Float32)::Float32 =
    if c <= 0.04045f0
        c / 12.92f0
    else
        ((c + 0.055f0) / 1.055f0)^2.4f0
    end

end
