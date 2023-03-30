#=
ytrace:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-01-03
=#

using JuliaFormatter: format
format(pwd(); overwrite = true)

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
using .Scene: add_sky, find_camera, MaterialPoint
using .SceneIO: load_scene, add_environment, save_image
using .Trace: make_trace_lights, make_trace_state, trace_samples, get_image
using Printf: @printf

function main(params::Params)
    if params.addsky
        println("addsky is not yet supported")
        params.addsky = false
    end
    if params.envname != ""
        println("envname is not yet supported")
        params.envname = ""
    end
    if params.denoise
        println("denoise is not yet supported")
        params.denoise = false
    end
    render_start = time_ns()
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
    println("building bvh...")
    bvh_start = time_ns()
    bvh = make_scene_bvh(scene, params.highqualitybvh, params.noparallel)
    @printf("built bvh in %s\n", format_seconds((time_ns() - bvh_start) / 1e9))
    println("making lights...")
    lights = make_trace_lights(scene, params)
    println("making state...")
    state = make_trace_state(scene, params)
    println("tracing samples...")
    stacks = params.noparallel ? 1 : Threads.nthreads()
    bvh_stacks = Vector{Vector{Int32}}(undef, stacks)
    bvh_sub_stacks = Vector{Vector{Int32}}(undef, stacks)
    for tid in 1:length(bvh_stacks)
        bvh_stacks[tid] = Vector{Int32}(undef, 64)
        bvh_sub_stacks[tid] = Vector{Int32}(undef, 64)
    end
    volume_stacks = Vector{Vector{MaterialPoint}}(undef, stacks)
    for tid in 1:length(bvh_stacks)
        volume_stacks[tid] = Vector{MaterialPoint}(undef, params.bounces)
    end
    sampling_start = time_ns()
    for _sample in 1:(params.batch):(params.samples)
        batch_start = time_ns()
        trace_samples(
            state,
            scene,
            bvh,
            lights,
            params,
            bvh_stacks,
            bvh_sub_stacks,
            volume_stacks,
        )
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
    @printf("total time: %s\n", format_seconds((time_ns() - render_start) / 1e9))
end

main(args::String) = main(parse_cli_args(split(args)))

function profile(resolution::Int = 500, samples::Int = 30)
    scenes = [
        #         "scenes/features1/features1",
        #         "scenes/features2/features2",
        #         "scenes/materials1/materials1",
        #         "scenes/materials2/materials2",
        #         "scenes/materials4/materials4",
        #         "scenes/shapes1/shapes1",
        #         "scenes/shapes2/shapes2",
        #         "scenes/bathroom1/bathroom1",
        "scenes/bathroom2/bathroom2",
        "scenes/coffee/coffee",
        "scenes/classroom/classroom",
        "scenes/kitchen/kitchen",
        "scenes/livingroom1/livingroom1",
        "scenes/livingroom2/livingroom2",
        "scenes/livingroom3/livingroom3",
        "scenes/staircase1/staircase1",
        "scenes/staircase2/staircase2",
        "scenes/ecosys/ecosys",
    ]
    for scene in scenes
        main(
            "--scene $scene.json --output $(scene)_naive.png --highqualitybvh true --resolution $resolution --samples $samples --batch 10 --sampler naive",
        )
    end
end

end

scenes = [
    "scenes/features1/features1",
    "scenes/features2/features2",
    "scenes/materials1/materials1",
    "scenes/materials2/materials2",
    "scenes/materials4/materials4",
    "scenes/shapes1/shapes1",
    "scenes/shapes2/shapes2",
    "scenes/bathroom1/bathroom1",
    "scenes/bathroom2/bathroom2",
    "scenes/coffee/coffee",
    "scenes/classroom/classroom",
    "scenes/kitchen/kitchen",
    "scenes/livingroom1/livingroom1",
    "scenes/livingroom2/livingroom2",
    "scenes/livingroom3/livingroom3",
    "scenes/staircase1/staircase1",
    "scenes/staircase2/staircase2",
    "scenes/ecosys/ecosys",
]
