return {
   {
      "nvim-telescope/telescope.nvim",
      tag = "0.1.5",
      dependencies = { "nvim-lua/plenary.nvim" },
      init = function()
         local builtin = require("telescope.builtin")
         vim.keymap.set("n", "<leader>t", builtin.find_files, {})
         vim.keymap.set("n", "<leader>\\", builtin.live_grep, {})
         --vim.keymap.set("n", "<leader>fb", builtin.buffers, {})
         --vim.keymap.set("n", "<leader>fh", builtin.help_tags, {})

         local actions = require("telescope.actions")

         require("telescope").setup({
            defaults = {
               mappings = {
                  i = {
                     ["<esc>"] = actions.close,
                     ["<c-q>"] = actions.move_selection_next,
                     ["<c-w>"] = actions.move_selection_next,
                     ["<c-n>"] = actions.move_selection_next,
                     ["<c-p>"] = actions.move_selection_previous,
                  },
               },
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
