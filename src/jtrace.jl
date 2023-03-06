#=
ytrace:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-01-03
=#

module Jtrace

include("cli.jl")
include("math.jl")
include("color.jl")
include("sampling.jl")
include("geometry.jl")
include("image.jl")
include("shape.jl")
include("scene.jl")
include("bvh.jl")
include("sceneio.jl")
include("shading.jl")
include("trace.jl")
using .Bvh: make_scene_bvh, verify_bvh
using .Cli: Params, parse_cli_args
using .Scene: add_sky, find_camera
using .SceneIO: load_scene, add_environment, save_image
using .Trace: make_trace_lights, make_trace_state, trace_samples, get_image
using Printf: @printf

function main(params::Params)
    if params.highqualitybvh
        println("highqualitybvh is still not implemented")
    end
    println("loading scene...")
    scene = load_scene(params.scene, params.noparallel)
    #     return
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
    render_ns = time_ns()
    for _sample in 1:(params.samples)
        sample_ns = time_ns()
        trace_samples(state, scene, bvh, lights, params)
        @printf(
            "sample %d/%d in %.3f s\n",
            state.samples,
            params.samples,
            (time_ns() - sample_ns) / 1e9
        )
    end
    @printf("rendered in %.3f s\n", (time_ns() - render_ns) / 1e9)
    println("saving image...")
    image = get_image(state)
    save_image(params.output, image)
    println("saved image to ", params.output)
end

main() = main(
    Params(
        "tests/features1/bunny.json";
        output = "tests/features1/bunny.png",
        samples = 1,
        resolution = 50,
        sampler = "naive",
        #             envhidden = true,
        noparallel = true,
    ),
)

using JuliaFormatter: format

if abspath(PROGRAM_FILE) == @__FILE__
    main(parse_cli_args(ARGS))
else
    format(pwd(); overwrite = true)
    println("first run is fake, ignore this")
    main(
        Params(
            "tests/features1/sphere.json";
            output = "tests/features1/sphere.png",
            samples = 1,
            resolution = 10,
            sampler = "naive",
            bounces = 0,
            envhidden = true,
        ),
    )
    #     scene = "tests/features1/features1"
    #     scene = "tests/features1/no_environ_floor"
    #     scene = "tests/features1/no_textures"
    scene = "tests/features1/bunny"
    #     scene = "tests/features2/features2"
    #     scene = "tests/features2/no_environ_floor"
    #     scene = "tests/materials1/materials1"
    #     scene = "tests/materials1/no_environ_floor"
    #     scene = "tests/materials2/materials2"
    #     scene = "tests/materials2/no_environ_floor"
    #     scene = "tests/materials4/materials4"
    #     scene = "tests/materials4/no_environ_floor"
    #     scene = "tests/shapes1/shapes1"
    #     scene = "tests/shapes1/no_environ_floor"
    #     scene = "tests/shapes2/shapes2"
    #     scene = "tests/shapes2/no_environ_floor"
    main(Params(
        "$(scene).json";
        output = "$(scene).png",
        samples = 1,
        #             resolution = 20,
        sampler = "naive",
        #             envhidden = true,
        #             noparallel = true,
    ))
end

end
