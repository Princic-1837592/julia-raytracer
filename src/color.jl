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

rgb_to_srgb(c::Vec4f)::Vec4f =
    Vec4f(rgb_to_srgb(c[1]), rgb_to_srgb(c[2]), rgb_to_srgb(c[3]), c[4])

rgb_to_srgb(rgb::Float32)::Float32 =
    (rgb <= 0.0031308f0) ? 12.92f0 * rgb : (1 + 0.055f0) * ^(rgb, 1 / 2.4f0) - 0.055f0

float_to_byte(a::Vec4f)::Vec4b = Vec4b(
    UInt8(clamp(trunc(Int, a[1] * 256), 0, 255)),
    UInt8(clamp(trunc(Int, a[2] * 256), 0, 255)),
    UInt8(clamp(trunc(Int, a[3] * 256), 0, 255)),
    UInt8(clamp(trunc(Int, a[4] * 256), 0, 255)),
)

end
