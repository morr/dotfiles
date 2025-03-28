local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.font = wezterm.font("MonacoLigaturized Nerd Font Mono")
config.font_size = 14.0

-- config.color_scheme = "Catppuccin Frappe"
config.color_schemes = {
  ["Catppuccin_Frappe_Custom"] = {
    -- ANSI Colors
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

    -- Other Colors
    background = "#38414f", -- Background Color
    foreground = "#beccc8", -- Foreground Color
    cursor_bg = "#ffffff", -- Cursor Color
    cursor_fg = "#000000", -- Cursor Text Color
    selection_bg = "#9bc9fa", -- Selection Color
    selection_fg = "#000000", -- Selected Text Color
  },
}
-- Use our custom color scheme
config.color_scheme = "Catppuccin_Frappe_Custom"

-- local function is_vim(pane)
--   local is_vim_env = pane:get_user_vars().IS_NVIM == "true"
--   if is_vim_env == true then
--     return true
--   end
--   -- This gsub is equivalent to POSIX basename(3)
--   -- Given "/foo/bar" returns "bar"
--   -- Given "c:\\foo\\bar" returns "bar"
--   local process_name = string.gsub(pane:get_foreground_process_name(), "(.*[/\\])(.*)", "%2")
--   return process_name == "nvim" or process_name == "vim"
-- end
--
-- --- cmd+keys that we want to send to neovim.
-- local super_vim_keys_map = {
--   a = utf8.char(0xAA),
--   c = utf8.char(0xAB),
--   f = utf8.char(0xAC),
--   r = utf8.char(0xAD),
--   s = utf8.char(0xAE),
--   t = utf8.char(0xAF),
--   w = utf8.char(0xBA),
--   x = utf8.char(0xBB),
--   ["\\"] = utf8.char(0xBC),
-- }
--
-- local function bind_super_key_to_vim(key)
--   return {
--     key = key,
--     mods = "CMD",
--     action = wezterm.action_callback(function(win, pane)
--       local char = super_vim_keys_map[key]
--       if char and is_vim(pane) then
--         -- pass the keys through to vim/nvim
--         win:perform_action({
--           SendKey = { key = char, mods = nil },
--         }, pane)
--       else
--         win:perform_action({
--           SendKey = {
--             key = key,
--             mods = "CMD",
--           },
--         }, pane)
--       end
--     end),
--   }
-- end
--
-- bind_super_key_to_vim("a")
-- bind_super_key_to_vim("c")
-- bind_super_key_to_vim("f")
-- bind_super_key_to_vim("r")
-- bind_super_key_to_vim("s")
-- bind_super_key_to_vim("t")
-- bind_super_key_to_vim("w")
-- bind_super_key_to_vim("x")
-- bind_super_key_to_vim("\\")

-- config.keys = {
--   { key = "s", mods = "CMD", action = wezterm.action.SendKey({ key = "S", mods = "CTRL" }) },
-- }

-- local function bind_keys_in_nvim(key, mods)
--   return function(window, pane)
--     local is_nvim = pane:get_foreground_process_name():match(".*/([^/]+)$") == "nvim"
--
--     if not is_nvim then
--       return
--     end
--
--     window:perform_action({ SendKey = { key = key, mods = mods } }, pane)
--   end
-- end
--
-- config.keys = {
--   { key = "p", mods = "CMD", action = wezterm.action_callback(bind_keys_in_nvim("p", "CTRL")) },
--   { key = "s", mods = "CMD", action = wezterm.action_callback(bind_keys_in_nvim("s", "CTRL")) },
-- }

local function is_neovim_process(pane)
  local process_name = pane:get_foreground_process_name()
  return process_name:match("n?vim") ~= nil
end

local function create_neovim_keybind(cmd_key, ctrl_key)
  return {
    key = cmd_key,
    mods = "CMD",
    action = wezterm.action_callback(function(window, pane)
      if is_neovim_process(pane) then
        -- Check if key is uppercase
        local mods = "CTRL"
        local key_to_send = ctrl_key

        -- For uppercase letters, we need to add SHIFT modifier and use lowercase key
        if key_to_send:match("[A-Z]") then
          mods = "CTRL|SHIFT"
          key_to_send = key_to_send:lower()
        end

        window:perform_action({ SendKey = { key = key_to_send, mods = mods } }, pane)
      else
        -- Pass the original key combination when not in Neovim
        window:perform_action({ SendKey = { key = cmd_key, mods = "CMD" } }, pane)
      end
    end),
  }
end

-- Generate key bindings from the mapping array
config.keys = {}
for _, key in ipairs({
  "a",
  "A",
  "c",
  "f",
  "r",
  "s",
  "t",
  "w",
  "x",
  "\\",
}) do
  table.insert(config.keys, create_neovim_keybind(key, key))
end

return config
