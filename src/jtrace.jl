#=
ytrace:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-01-03
=#

module Jtrace

include("utils.jl")
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
using .Utils: format_seconds
using .Bvh: make_scene_bvh
using .Cli: Params, parse_cli_args
using .Scene: add_sky, find_camera
using .SceneIO: load_scene, add_environment, save_image
using .Trace: make_trace_lights, make_trace_state, trace_samples, get_image
using Printf: @printf

function main(params::Params)
    render_start = time_ns()
    if params.highqualitybvh
        println("high quality bvh is still not implemented")
    end
    @printf("loading scene %s...\n", params.scene)
    load_bs = time_ns()
    scene = load_scene(params.scene, params.noparallel)
    @printf("loaded scene in %s\n", format_seconds((time_ns() - load_bs) / 1e9))
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
    println("making lights...")
    lights = make_trace_lights(scene, params)
    println("making state...")
    state = make_trace_state(scene, params)
    println("tracing samples...")
    stacks = params.noparallel ? 1 : Threads.nthreads()
    bvh_stacks = Vector{Vector{Int32}}(undef, stacks)
    bvh_sub_stacks = Vector{Vector{Int32}}(undef, stacks)
    for tid in 1:length(bvh_stacks)
        bvh_stacks[tid] = Vector{Int32}(undef, 32)
        bvh_sub_stacks[tid] = Vector{Int32}(undef, 32)
    end
    sampling_start = time_ns()
    for _sample in 1:(params.batch):(params.samples)
        batch_start = time_ns()
        trace_samples(state, scene, bvh, lights, params, bvh_stacks, bvh_sub_stacks)
        now = time_ns()
        @printf(
            "sample %3d/%3d in %s ETC: %s\n",
            state.samples,
            params.samples,
            format_seconds((now - batch_start) / 1e9),
            format_seconds(
                (now - sampling_start) / 1e9 / state.samples *
                (params.samples - state.samples),
            ),
        )
    end
    render_ns = (time_ns() - sampling_start) / 1e9
    @printf("rendered in %s (%.3fs)\n", format_seconds(render_ns), render_ns)
    println("saving image...")
    image = get_image(state)
    save_image(params.output, image)
    println("saved image to ", params.output)
end

main(args::String) = main(parse_cli_args(split(args)))

using JuliaFormatter: format

if abspath(PROGRAM_FILE) == @__FILE__
    main(parse_cli_args(ARGS))
else
    format(pwd(); overwrite = true)
    #     scene = "tests/features1/features1"
    scene = "tests/features1/features1_matte"
    #     scene = "tests/features1/no_environ_floor"
    #     scene = "tests/features1/no_textures"
    #     scene = "tests/features1/bunny"
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
    #     main(
    #         Params(
    #             "$(scene).json";
    #             output = "$(scene).png",
    #             samples = 1,
    #                                     resolution = 100,
    #             sampler = "naive",
    #             envhidden = true,
    #             #             noparallel = true,
    #             bounces = 8,
    #         ),
    #     )
end

end
