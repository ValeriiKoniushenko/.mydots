local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- config.show_close_tab_button_in_tabs = false
config.show_new_tab_button_in_tab_bar = false
config.window_decorations = "TITLE | RESIZE"
config.default_cursor_style = "SteadyBar"
config.cursor_thickness = "2px"
config.automatically_reload_config = true
config.window_close_confirmation = "NeverPrompt"
config.adjust_window_size_when_changing_font_size = false
config.check_for_updates = true
config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = false
config.font_size = 11.5
config.exit_behavior = "Close"
config.font = wezterm.font("JetBrains Mono")
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.window_padding = {
    left = 4,
    right = 4,
    top = 10,
    bottom = 4,
}
config.window_background_opacity = 0.92
config.initial_cols = 140
config.colors = {
  tab_bar = {

    active_tab = {
      bg_color = '#fff',
      fg_color = '#000',
      intensity = 'Bold',
      underline = 'None',
      italic = false,
      strikethrough = false,
    },

    inactive_tab = {
        intensity = 'Half',
        bg_color = '#131313',
        fg_color = '#808080',
    },

    inactive_tab_hover = {
      bg_color = '#3b3052',
      fg_color = '#909090',
      italic = true,

      -- The same options that were listed under the `active_tab` section above
      -- can also be used for `inactive_tab_hover`.
    },

    -- The new tab button that let you create new tabs
    new_tab = {
      bg_color = '#fff',
      fg_color = '#808080',

      -- The same options that were listed under the `active_tab` section above
      -- can also be used for `new_tab`.
    },

    -- You can configure some alternate styling when the mouse pointer
    -- moves over the new tab button
    new_tab_hover = {
      bg_color = '#3b3052',
      fg_color = '#909090',
      italic = true,

      -- The same options that were listed under the `active_tab` section above
      -- can also be used for `new_tab_hover`.
    },
  },
}

local moveOffset = 1
local mainMod = 'ALT|SHIFT'
config.keys = {
    {
        key = 'f',
        mods = mainMod,
        action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
    },
    {
        key = 'd',
        mods = mainMod,
        action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
    },
    {
        key = 'c',
        mods = mainMod,
        action = wezterm.action.CloseCurrentPane { confirm = true },
    },
    {
        key = 'LeftArrow',
        mods = mainMod,
        action = wezterm.action.AdjustPaneSize { 'Left', moveOffset },
    },
    {
        key = 'DownArrow',
        mods = mainMod,
        action = wezterm.action.AdjustPaneSize { 'Down', moveOffset },
    },
    { 
        key = 'UpArrow', 
        mods = mainMod, 
        action = wezterm.action.AdjustPaneSize { 'Up', moveOffset } 
    },
    {
        key = 'RightArrow',
        mods = mainMod,
        action = wezterm.action.AdjustPaneSize { 'Right', moveOffset },
    },
    { key = 'q', mods = mainMod, action = wezterm.action.ActivatePaneByIndex(0) },
    { key = 'w', mods = mainMod, action = wezterm.action.ActivatePaneByIndex(1) },
    { key = 'e', mods = mainMod, action = wezterm.action.ActivatePaneByIndex(2) },
    { key = 'r', mods = mainMod, action = wezterm.action.ActivatePaneByIndex(3) },
}

return config
