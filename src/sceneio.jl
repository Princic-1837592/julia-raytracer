import ArgParse
import JSON



#=
    Parses command line interface arguments.
=#
function parse_cli()
    parser = ArgParseSettings()

    @add_arg_table! settings begin
        "--scene", "-s"
            help = "scene filename" #TODO: add a check to return or raise an error if the input is not in .ply format
            required = true
        "--output", "-o"
            help = "output filename"
            default = "output.png"      #TODO: in case we export to jpg, change it
            required = false
        "--addsky"
            help = "add sky"
            required = false
        "--resolution"
            help = "image resolution"
    end

    return parse_args(parser)
end



#=
    Loads a scene in .ply format
=#
function load_ply_scene(filename::String, scene::scene_data) #TODO: implement scene_data structure
    shape = shape_data() #TODO: implement shape_data structure
    if !load_shape(filename, shape)
        return false
    end

    scene.shapes.push(shape)
    scene.instances.push() #TODO: implement (see yocto_sceneio.cpp:4301)

    #fix scene
    add_missing_material(scene) #TODO: implement all of these
    add_missing_camera(scene)
    add_missing_radius(scene)
    add_missing_lights(scene)

    return true
end


#=
    Add environment
=#
function add_environment(filename::String, scene::scene_data)
    texture = texture_data() #TODO: implement texture_data structure
    if !load_texture(filename, texture)
        return false
    end

    scene.textures.push(texture)
    scene.environments.push() #TODO: implement (see yocto_sceneio.cpp:2787)

    return true
end