-- Shared display layout; unmatched outputs use the fallback rule.
hl.env("GDK_SCALE", "1")
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.25 })
hl.monitor({ output = "DP-2", mode = "3840x2160@240.02Hz", position = "0x0", scale = 1.25 })
hl.monitor({ output = "DP-3", mode = "3440x1440@120.00Hz", position = "160x-1152", scale = 1.25 })
