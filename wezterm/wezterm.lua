local wezterm = require("wezterm")
local config = require("config")
require("events")
wezterm.font("MesloLGS NF")
config.color_scheme = "carbonfox"
config.enable_wayland = false

return config
