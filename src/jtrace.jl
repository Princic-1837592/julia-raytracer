#=
ytrace:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-01-03
=#

include("math.jl")
include("shape.jl")
include("bvh.jl")
include("cli.jl")
include("scene.jl")
include("sceneio.jl")
include("trace.jl")
using .Bvh: make_scene_bvh
using .Cli: parse_cli_args
using .Scene: add_sky, find_camera
using .SceneIO: load_scene, add_environment
using .Trace: make_trace_lights, make_trace_state, trace_samples

function main()
    params = parse_cli_args()
    println("loading scene...")
    scene = load_scene(params["scene"])
    #     dump(scene)
    if params["addsky"]
        println("adding sky...")
        add_sky(scene)
    end
    if params["envname"] != ""
        println("adding environment...")
        add_environment(scene, params["envname"])
    end
    println("finding camera...")
    params["camera"] == find_camera(scene, params["camera"])
    println("building bvh...")
    bvh = make_scene_bvh(scene)
    println("making lights...")
    lights = make_trace_lights(scene, params)
    println("making state...")
    state = make_trace_state(scene, params)
    println("tracing samples...")
    for _sample in 1:params["samples"]
        sample_time = time_ns()
        trace_samples(state, scene, bvh, lights, params)
        #         println("rander sample $(state.samples)/$(params.samples)")
        #         sleep(rand(Float16))
        #         println("rander sample $((time_ns() - sample_time) / 1_000_000_000)s")
    end
    println("saving image...")
    #save image todo
end

main()
