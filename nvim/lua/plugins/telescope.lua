return {
  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.5",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-lua/popup.nvim",
      "BurntSushi/ripgrep",
      "nvim-telescope/telescope-live-grep-args.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build",
      },
    },
    init = function()
      local builtin = require("telescope.builtin")
      vim.keymap.set(
        "n",
        "<leader>t",
        builtin.find_files,
        { desc = "Telescope files" }
      )
      vim.keymap.set(
        "n",
        "<leader>\\",
        builtin.live_grep,
        { desc = "Telescope live grep" }
      )
      vim.keymap.set(
        "n",
        "<leader>|",
        require("telescope").extensions.live_grep_args.live_grep_args,
        { desc = "Telescope live grep args" }
      )
      vim.keymap.set(
        "n",
        "<leader>b",
        builtin.buffers,
        { desc = "Telescope buffers" }
      )
      vim.keymap.set(
        "n",
        "<leader>q",
        builtin.quickfix,
        { desc = "Telescope quickfix" }
      )
      -- vim.keymap.set("n", "<leader>fh", builtin.help_tags, {})

      local actions = require("telescope.actions")
      local telescope = require("telescope")
      local lga_actions = require("telescope-live-grep-args.actions")

      telescope.load_extension("fzf")
      telescope.setup({
        defaults = {
          mappings = {
            i = {
              ["<esc>"] = actions.close,
              ["<c-q>"] = actions.add_to_qflist,
              -- ["<c-w>"] = actions.move_selection_next,
              ["<c-n>"] = actions.move_selection_next,
              ["<c-p>"] = actions.move_selection_previous,
            },
          },
          -- logic of previewing images
          preview = {
            mime_hook = function(filepath, bufnr, opts)
              local is_image = function(image_filepath)
                local image_extensions = { "png", "jpg", "mp4", "webm", "pdf" } -- Supported image formats
                local split_path =
                  vim.split(image_filepath:lower(), ".", { plain = true })
                local extension = split_path[#split_path]
                return vim.tbl_contains(image_extensions, extension)
              end
              if is_image(filepath) then
                local term = vim.api.nvim_open_term(bufnr, {})
                local function send_output(_, data, _)
                  for _, d in ipairs(data) do
                    vim.api.nvim_chan_send(term, d .. "\r\n")
                  end
                end
                vim.fn.jobstart({
                  "chafa",
                  filepath, -- Terminal image viewer command
                }, {
                  on_stdout = send_output,
                  stdout_buffered = true,
                  pty = true,
                })
              else
                require("telescope.previewers.utils").set_preview_message(
                  bufnr,
                  opts.winid,
                  "Binary cannot be previewed"
                )
              end
            end,
          },
        },
        extensions = {
          fzf = {
            fuzzy = true, -- false will only do exact matching
            override_generic_sorter = true, -- override the generic sorter
            override_file_sorter = true, -- override the file sorter
            case_mode = "smart_case", -- or "ignore_case" or "respect_case"
          },
          live_grep_args = {
            auto_quoting = true, -- enable/disable auto-quoting
            -- define mappings, e.g.
            -- mappings = { -- extend mappings
            --   i = {
            --     ["<C-k>"] = lga_actions.quote_prompt(),
            --     ["<C-i>"] = lga_actions.quote_prompt({ postfix = " --iglob " }),
            --     ["<C-f"] = lga_actions.quote_prompt({ postfix = " -t" }),
            --   },
            -- },
            -- ... also accepts theme settings, for example:
            -- theme = "dropdown", -- use dropdown theme
            -- theme = { }, -- use own theme spec
            -- layout_config = { mirror=true }, -- mirror preview pane
          },
          --    media_files = {
          --       -- filetypes whitelist
          --       -- defaults to {"png", "jpg", "mp4", "webm", "pdf"}
          --       filetypes = {"png", "webp", "jpg", "jpeg"},
          --       -- find command (defaults to `fd`)
          --       find_cmd = "rg"
          --    }
        },
      })
    end,
    --opts = {
    --   pickers = {
    --    find_files = {
    --      theme = "dropdown",
    --    },
    --  },
    --},
  },
}
