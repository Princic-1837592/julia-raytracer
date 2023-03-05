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

end
