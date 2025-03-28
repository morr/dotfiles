local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.font = wezterm.font("MonacoLigaturized Nerd Font Mono")
config.font_size = 15.0

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

return config
