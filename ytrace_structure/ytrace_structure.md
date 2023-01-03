`ytrace main()`:

* <code>update_trace_params()</code> [yocto_sceneio]
* <code>save_trace_params()</code> [yocto_sceneio]
* <code>print_info()</code> [yocto_cli]
* <code>load_scene()</code> [yocto_sceneio]
* <code>add_sky()</code> [yocto_scene]
* <code>add_environment()</code> [yocto_sceneio]
* <code>find_camera()</code> [yocto_scene]
* <code>tesselate_subdivs()</code> [yocto_scene]
* <code>make_trace_bvh()</code> [yocto_trace]
* <code>make_trace_lights()</code> [yocto_trace]
* <code>if (lights.mpty() && is_sampler_lit())</code> [yocto_trace]
* <code>make_trace_state</code> [yocto_trace]
* <code>if (!interactive)</code>
    * <code>for (each sample):</code>
        * <code>trace_samples()</code> [yocto_trace]
        * <code>if (conditions)</code>
            * <code>get_image()</code> [yocto_trace]
            * <code>replace_extension()</code> [yocto_sceneio]
            * <code>save_image()</code> [yocto_sceneio]
    * <code>get_image()</code> [yocto_sceneio]
    * <code>save_image()</code> [yocto_sceneio]