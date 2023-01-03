#=
shape:
- Julia version: 
- Author: Andrea
- Date: 2023-01-03
=#

using LinearAlgebra
using StaticArrays

#todo capire quale tipo di vettore usare
mutable struct BvhTree
    nodes
    primitives
end
