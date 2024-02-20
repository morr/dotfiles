return {
   {
      -- "m4xshen/catppuccinight.nvim",
      "catppuccin/nvim",
      name = "catppuccin",
      opts = {
         -- flavour = "latte", -- latte, frappe, macchiato, mocha
         flavour = "frappe", -- latte, frappe, macchiato, mocha
         -- flavour = "macchiato", -- latte, frappe, macchiato, mocha
         -- flavour = "mocha", -- latte, frappe, macchiato, mocha
         -- custom_highlights = function(colors)
         --    return {
         --       VertSplit = { fg = colors.surface0 },
         --    }
         -- end,
         integrations = {
            notify = true,
         },
      },
      init = function()
         vim.cmd.colorscheme("catppuccin")
      end,
   },
   {
      "utilyre/barbecue.nvim",
      name = "barbecue",
      version = "*",
      theme = "catppuccin",
      -- theme = "dracula",
      dependencies = {
         "SmiteshP/nvim-navic",
         "nvim-tree/nvim-web-devicons",
      },
      opts = {
         show_dirname = false,
         show_basename = false,
      },
   },
   {
      "rcarriga/nvim-notify",
      opts = {},
      config = function()
         vim.notify = require("notify")
      end,
   },
   {
      "aznhe21/actions-preview.nvim",
      config = function()
         vim.keymap.set(
            { "v", "n" },
            "<Leader>ca",
            require("actions-preview").code_actions
         )
      end,
   },
   {
      "lukas-reineke/virt-column.nvim",
      opts = {},
   },
   {
      "m4xshen/smartcolumn.nvim",
      opts = {
         disabled_filetypes = {
            "netrw",
            "NvimTree",
            "Lazy",
            "mason",
            "help",
            "text",
            "markdown",
            "tex",
            "html",
         },
         scope = "window",
      },
   },
   {
      "nvim-lualine/lualine.nvim",
      dependencies = { "nvim-tree/nvim-web-devicons" },
      opts = {
         options = {
            theme = "catppuccin",
            -- theme = "dracula",
            globalstatus = true,
         },
         sections = {
            lualine_c = {},
         },
      },
      init = function()
         vim.opt.showmode = false
      end,
   },
   {
      "akinsho/bufferline.nvim",
      version = "v3.*",
      dependencies = "nvim-tree/nvim-web-devicons",
      opts = {
         options = {
            separator_style = "slant",
            mode = "tabs",
            offsets = {
               {
                  filetype = "NvimTree",
                  text = " File Explorer",
                  highlight = "Directory",
                  separator = false,
               },
            },
         },
      },
   },
   {
      "folke/which-key.nvim",
      event = "VeryLazy",
      init = function()
         vim.o.timeout = true
         vim.o.timeoutlen = 300
      end,
      opts = {
         -- your configuration comes here
         -- or leave it empty to use the default settings
         -- refer to the configuration section below
      }
   },
   { -- fancy ui for neovim select dialogs
      "stevearc/dressing.nvim",
      event = "VeryLazy",
   },
}
