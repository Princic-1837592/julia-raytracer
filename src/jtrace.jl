#=
ytrace:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-01-03
=#

module Jtrace

include("cli.jl")
include("math.jl")
include("sampling.jl")
include("geometry.jl")
include("image.jl")
include("shape.jl")
include("scene.jl")
include("bvh.jl")
include("sceneio.jl")
include("trace.jl")
using .Bvh: make_scene_bvh, verify_bvh
using .Cli: Params, parse_cli_args
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

using JuliaFormatter: format

if abspath(PROGRAM_FILE) == @__FILE__
    main(parse_cli_args(ARGS))
else
    format(pwd(); overwrite = true)
    main(
        Params(
            "tests/features1/bunny.json";
            output = "tests/test_scene.png",
            samples = 1,
            resolution = 100,
        ),
    )
end

end
