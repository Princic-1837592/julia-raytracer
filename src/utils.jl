#=
utils:
- Julia version: 1.8.3
- Author: Andrea
- Date: 2023-03-11
=#

module Utils

function format_seconds(seconds::Float64)
    hours = floor(Int32, seconds / 3600)
    minutes = floor(Int32, (seconds - hours * 3600) / 60)
    seconds = seconds - hours * 3600 - minutes * 60
    i_seconds = floor(Int32, seconds)
    f_seconds = seconds - i_seconds
    #     if hours != 0
    #         "$(string(minutes, pad = 2)):$(string(i_seconds, pad = 2)).$(string(round(Int32, f_seconds * 1000), pad = 3))"
    #     elseif minutes == 0
    #         "$(string(i_seconds, pad = 2)).$(string(round(Int32, f_seconds * 1000), pad = 3))"
    #     else
    #         "$(string(hours)):$(string(minutes, pad = 2)):$(string(i_seconds, pad = 2)).$(string(round(Int32, f_seconds * 1000), pad = 3))"
    #     end
    if hours == 0
        if minutes == 0
            "$(string(i_seconds, pad = 2)).$(string(round(Int32, f_seconds * 1000), pad = 3))"
        else
            "$(string(minutes, pad = 2)):$(string(i_seconds, pad = 2)).$(string(round(Int32, f_seconds * 1000), pad = 3))"
        end
    else
        "$(string(hours,pad=2)):$(string(minutes, pad = 2)):$(string(i_seconds, pad = 2)).$(string(round(Int32, f_seconds * 1000), pad = 3))"
    end
end

end
