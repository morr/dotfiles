local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.font = wezterm.font("MonacoLigaturized Nerd Font Mono")
config.font_size = 14.0

config.initial_cols = 194
config.initial_rows = 50

config.window_decorations = "RESIZE"

-- config.color_scheme = "Catppuccin Frappe"
config.color_schemes = {
  ["Catppuccin_Frappe_Custom"] = {
    ansi = {
      "#000000", -- Black (Ansi 0)
      "#ee5849", -- Red (Ansi 1)
      "#75a774", -- Green (Ansi 2)
      "#d1b93b", -- Yellow (Ansi 3)
      "#47a7d1", -- Blue (Ansi 4)
      "#cc87ce", -- Magenta (Ansi 5)
      "#99ccd4", -- Cyan (Ansi 6)
      "#cadbda", -- White (Ansi 7)
    },
    brights = {
      "#000000", -- Bright Black (Ansi 8)
      "#ee5849", -- Bright Red (Ansi 9)
      "#75a774", -- Bright Green (Ansi 10)
      "#d1b93b", -- Bright Yellow (Ansi 11)
      "#47a7d1", -- Bright Blue (Ansi 12)
      "#cc87ce", -- Bright Magenta (Ansi 13)
      "#99ccd4", -- Bright Cyan (Ansi 14)
      "#cadbda", -- Bright White (Ansi 15)
    },
    background = "#38414f", -- Background Color
    foreground = "#beccc8", -- Foreground Color
    cursor_bg = "#ffffff", -- Cursor Color
    cursor_fg = "#000000", -- Cursor Text Color
    selection_bg = "#9bc9fa", -- Selection Color
    selection_fg = "#000000", -- Selected Text Color
  },
}
config.color_scheme = "Catppuccin_Frappe_Custom"

-- compatibility with neovim
local function is_neovim_process(pane)
  local process_name = pane:get_foreground_process_name()
  return process_name:match("n?vim") ~= nil
end

local function create_neovim_keybind(key)
  return {
    key = key,
    mods = "CMD",
    action = wezterm.action_callback(function(window, pane)
      if is_neovim_process(pane) then
        local mods = "ALT"
        local key_to_send = key

        if key_to_send:match("[A-Z]") then
          mods = "ALT|SHIFT"
          key_to_send = key_to_send:lower()
        end

        window:perform_action({ SendKey = { key = key_to_send, mods = mods } }, pane)
      else
        window:perform_action({ SendKey = { key = key, mods = "CMD" } }, pane)
      end
    end),
  }
end

config.keys = {
  create_neovim_keybind("a"),
  create_neovim_keybind("A"),
  create_neovim_keybind("c"),
  create_neovim_keybind("f"),
  create_neovim_keybind("r"),
  create_neovim_keybind("s"),
  -- create_neovim_keybind("w"),
  create_neovim_keybind("x"),
  create_neovim_keybind("\\"),
  {
    key = "w",
    mods = "CMD",
    action = wezterm.action_callback(function(window, pane)
      if is_neovim_process(pane) then
        window:perform_action({ SendKey = { key = "w", mods = "ALT" } }, pane)
      else
        window:perform_action(wezterm.action.CloseCurrentTab({ confirm = false }), pane)
      end
    end),
  },
  -- cmd + t - open new tab
  {
    key = "t",
    mods = "CMD",
    action = wezterm.action_callback(function(window, pane)
      window:perform_action(wezterm.action.SpawnTab("CurrentPaneDomain"), pane)
    end),
  },
  -- cmd + n - open new window
  {
    key = "n",
    mods = "CMD",
    action = wezterm.action.SpawnWindow,
  },
  -- option+left - move cursor one word left
  {
    key = "LeftArrow",
    mods = "OPT",
    action = wezterm.action.SendKey({ key = "b", mods = "ALT" }),
  },

  -- option+right - move cursor one word right
  {
    key = "RightArrow",
    mods = "OPT",
    action = wezterm.action.SendKey({ key = "f", mods = "ALT" }),
  },

  -- cmd+left - move cursor to the start of line
  {
    key = "LeftArrow",
    mods = "CMD",
    action = wezterm.action.SendKey({ key = "a", mods = "CTRL" }),
  },

  -- cmd+end - move cursor to the end of line
  {
    key = "RightArrow",
    mods = "CMD",
    action = wezterm.action.SendKey({ key = "e", mods = "CTRL" }),
  },

  -- option+del - delete previous word
  {
    key = "Backspace",
    mods = "OPT",
    action = wezterm.action.SendKey({ key = "w", mods = "CTRL" }),
  },

  -- cmd+del - delete to the start of line
  {
    key = "Backspace",
    mods = "CMD",
    action = wezterm.action.SendKey({ key = "u", mods = "CTRL" }),
  },
}

return config
