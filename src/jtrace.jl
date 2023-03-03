#=
ytrace:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-01-03
=#

module Jtrace

include("math.jl")
include("sampling.jl")
include("geometry.jl")
include("image.jl")
include("shape.jl")
include("cli.jl")
include("scene.jl")
include("bvh.jl")
include("sceneio.jl")
include("trace.jl")
using .Bvh: make_scene_bvh, verify_bvh
using .Cli: Params
using .Scene: add_sky, find_camera
using .SceneIO: load_scene, add_environment, save_image
using .Trace: make_trace_lights, make_trace_state, trace_samples, get_image

function main(params::Params)
    if params.highqualitybvh
        println("highqualitybvh is still not implemented")
    end
    println("loading scene...")
    scene = load_scene(params.scene, params.noparallel)
    #     dump(scene)
    if params.addsky
        println("adding sky...")
        add_sky(scene)
    end
    if params.envname != ""
        println("adding environment...")
        add_environment(scene, params.envname)
    end
    println("finding camera...")
    params.camera = find_camera(scene, params.camera)
    #todo(?) subdivs
    println("building bvh...")
    bvh = make_scene_bvh(scene, params.highqualitybvh, params.noparallel)
    println(if verify_bvh(bvh)
        "bvh is valid"
    else
        "bvh is invalid"
    end)
    println("making lights...")
    lights = make_trace_lights(scene, params)
    println("making state...")
    state = make_trace_state(scene, params)
    println("tracing samples...")
    for _sample in 1:(params.samples)
        trace_samples(state, scene, bvh, lights, params)
        println("rander sample $(state.samples)/$(params.samples)")
    end
    println("saving image...")
    image = get_image(state)
    save_image(params.output, image)
end

end
