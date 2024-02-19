return {
   {
      "lewis6991/gitsigns.nvim",
      opts = {},
   },
   {
      "NeogitOrg/neogit",
      dependencies = {
         "nvim-lua/plenary.nvim", -- required
         "nvim-telescope/telescope.nvim", -- optional
         { "sindrets/diffview.nvim" } -- optional
      },
      config = true,
      -- keys = {
      --    { "<Leader>g", ":Neogit<CR>" },
      --    { "<Leader>d", ":DiffviewOpen<CR><c-w><right>" },
      -- },
      init = function()
         vim.keymap.set("n", "<leader>g", ":Neogit<CR>", { desc = "Neogit" })
         vim.keymap.set("n", "<leader>d", ":DiffviewOpen<CR><c-w><right>", { desc = "Diffview" })
      end

   }
}
