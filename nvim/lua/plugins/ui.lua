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
    "folke/noice.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    event = "VeryLazy",
    opts = {
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true, -- requires hrsh7th/nvim-cmp
        },
      },
      presets = {
        -- bottom_search = true, -- use a classic bottom cmdline for search
        -- command_palette = true, -- position the cmdline and popupmenu together
        long_message_to_split = true, -- long messages will be sent to a split
        -- inc_rename = true, -- enables an input dialog for inc-rename.nvim
        -- lsp_doc_border = false, -- add a border to hover docs and signature help
      },
      -- disable messages display via nvim-notify
      messages = {
        enabled = false,
      },
      routes = {
        -- hide search vitual text
        {
          filter = {
            event = "msg_show",
            kind = "search_count",
          },
          opts = { skip = true },
        },
        -- hide "written" messages
        {
          filter = {
            event = "msg_show",
            kind = "",
            find = "written",
          },
          opts = { skip = true },
        },
      },
    },
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
        -- lualine_x = {
        --   require("noice").api.statusline.mode.get,
        --   cond = require("noice").api.statusline.mode.has,
        --   color = { fg = "#ff9e64" },
        -- },
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
      presets = {
        bottom_search = true, -- use a classic bottom cmdline for search
        command_palette = true, -- position the cmdline and popupmenu together
        long_message_to_split = true, -- long messages will be sent to a split
        inc_rename = false, -- enables an input dialog for inc-rename.nvim
        lsp_doc_border = false, -- add a border to hover docs and signature help
      },
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    },
  },
  { -- fancy ui for neovim select dialogs
    "stevearc/dressing.nvim",
    event = "VeryLazy",
  },
}
