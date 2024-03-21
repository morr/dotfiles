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
  -- {
  --   "aznhe21/actions-preview.nvim",
  --   config = function()
  --     vim.keymap.set(
  --       { "v", "n" },
  --       "<Leader>ca",
  --       require("actions-preview").code_actions
  --     )
  --   end,
  -- },
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
        icons_enabled = true,
        theme = "auto",
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
        disabled_filetypes = {
          statusline = {},
          winbar = {},
        },
        ignore_focus = {},
        always_divide_middle = true,
        globalstatus = false,
        refresh = {
          statusline = 1000,
          tabline = 1000,
          winbar = 1000,
        },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = {
          "branch",
          "diff",
          "diagnostics",
          -- {
          --   "diagnostics",
          --   sources = { "nvim_diagnostic", "nvim_lsp" },
          --   sections = { "error", "warn", "info", "hint" },
          --   diagnostics_color = {
          --     -- Same values as the general color option can be used here.
          --     error = "DiagnosticError", -- Changes diagnostics' error color.
          --     warn = "DiagnosticWarn", -- Changes diagnostics' warn color.
          --     info = "DiagnosticInfo", -- Changes diagnostics' info color.
          --     hint = "DiagnosticHint", -- Changes diagnostics' hint color.
          --   },
          --   symbols = { error = "E", warn = "W", info = "I", hint = "H" },
          --   colored = true, -- Displays diagnostics status in color if set to true.
          --   update_in_insert = false, -- Update diagnostics in insert mode.
          --   always_visible = false, -- Show diagnostics even if there are none.
          -- },
        },
        lualine_c = {
          {
            "filename",
            file_status = true, -- Displays file status (readonly status, modified status)
            newfile_status = false, -- Display new file status (new file means no write after created)
            path = 3, -- 0: Just the filename
            -- 1: Relative path
            -- 2: Absolute path
            -- 3: Absolute path, with tilde as the home directory
            -- 4: Filename and parent dir, with tilde as the home directory

            shorting_target = 40, -- Shortens path to leave 40 spaces in the window
            -- for other components. (terrible name, any suggestions?)
            symbols = {
              modified = "[+]", -- Text to show when the file is modified.
              readonly = "[-]", -- Text to show when the file is non-modifiable or readonly.
              unnamed = "[No Name]", -- Text to show for unnamed buffers.
              newfile = "[New]", -- Text to show for newly created file before first write
            },
          },
        },
        lualine_x = { "encoding", "fileformat", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { "filename" },
        lualine_x = { "location" },
        lualine_y = {},
        lualine_z = {},
      },
      -- tabline = {
      --   lualine_a = {
      --
      --     {
      --       "tabs",
      --       tab_max_length = 40, -- Maximum width of each tab. The content will be shorten dynamically (example: apple/orange -> a/orange)
      --       max_length = vim.o.columns / 3, -- Maximum width of tabs component.
      --       -- Note:
      --       -- It can also be a function that returns
      --       -- the value of `max_length` dynamically.
      --       mode = 1, -- 0: Shows tab_nr
      --       -- 1: Shows tab_name
      --       -- 2: Shows tab_nr + tab_name
      --
      --       path = 1, -- 0: just shows the filename
      --       -- 1: shows the relative path and shorten $HOME to ~
      --       -- 2: shows the full path
      --       -- 3: shows the full path and shorte $HOME to ~
      --
      --       -- Automatically updates active tab color to match color of other components (will be overidden if buffers_color is set)
      --       use_mode_colors = true,
      --
      --       -- tabs_color = {
      --       --   -- Same values as the general color option can be used here.
      --       --   active = "lualine_{section}_normal", -- Color for active tab.
      --       --   inactive = "lualine_{section}_inactive", -- Color for inactive tab.
      --       -- },
      --
      --       show_modified_status = true, -- Shows a symbol next to the tab name if the file has been modified.
      --       symbols = {
      --         modified = "[+]", -- Text to show when the file is modified.
      --       },
      --
      --       fmt = function(name, context)
      --         -- Show + if buffer is modified in tab
      --         local buflist = vim.fn.tabpagebuflist(context.tabnr)
      --         local winnr = vim.fn.tabpagewinnr(context.tabnr)
      --         local bufnr = buflist[winnr]
      --         local mod = vim.fn.getbufvar(bufnr, "&mod")
      --
      --         return name .. (mod == 1 and " +" or "")
      --       end,
      --     },
      --   },
      --   -- lualine_a = {},
      --   lualine_b = {},
      --   lualine_c = {},
      --   -- lualine_b = { "branch" },
      --   -- lualine_c = { "filename" },
      --   lualine_x = {},
      --   lualine_y = {},
      --   lualine_z = {},
      -- },
      winbar = {},
      inactive_winbar = {},
      extensions = {},
    },
    init = function()
      vim.opt.showmode = false
    end,
  },
  {
    "akinsho/bufferline.nvim",
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
            asdseparator = false,
          },
        },
        show_close_icon = false,
        -- name_formatter = function(buf) -- buf contains:
        --   -- name                | str        | the basename of the active file
        --   -- path                | str        | the full path of the active file
        --   -- bufnr (buffer only) | int        | the number of the active buffer
        --   -- buffers (tabs only) | table(int) | the numbers of the buffers in the tab
        --   -- tabnr (tabs only)   | int        | the "handle" of the tab, can be converted to its ordinal number using: `vim.api.nvim_tabpage_get_number(buf.tabnr)`
        -- end,

        diagnostics = "nvim_lsp",
        diagnostics_indicator = function(
          count,
          level,
          _diagnostics_dict,
          context
        )
          -- vim.notify(vim.inspect(diagnostics_dict))
          if context.buffer:current() then
            local icon = level:match("error") and " " or " "
            return " " .. icon .. count

            -- local signs =
            --   { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
            -- local indicator = (
            --   diagnostics_dict.error
            --     and signs.Error .. diagnostics_dict.error .. " "
            --   or ""
            -- )
            --   .. (diagnostics_dict.warning and signs.Warn .. diagnostics_dict.warning or "")
            --   .. (
            --     diagnostics_dict.hint and signs.Hint .. diagnostics_dict.hint
            --     or ""
            --   )
            --
            -- return vim.trim(indicator)
          end

          return ""
        end,
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
