#=
trace:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-02-26
=#

module Trace
struct TraceState
    width::Int
    height::Int
    samples::Int
    image::Array{Float32,1}
end
function make_trace_lights(scene, params) end
function make_trace_state(scene, params) end
function trace_samples(state, scene, bvh, lights, params) end
end
