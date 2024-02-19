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
         vim.keymap.set("n", "<leader>gg", "<cmd>Neogit<CR>", { desc = "Neogit" })
         vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewOpen<CR><c-w><right>", { desc = "Diffview" })

         local group = vim.api.nvim_create_augroup("MyCustomNeogitEvents", { clear = true })
         vim.api.nvim_create_autocmd("User", {
            pattern = {
               -- "NeogitCherryPick",
               -- "NeogitBranchCheckout",
               -- "NeogitBranchCreated",
               -- "NeogitBranchDelete",
               -- "NeogitBranchReset",
               -- "NeogitBranchRename",
               -- "NeogitRebase",
               -- "NeogitReset",
               -- "NeogitTagCreate",
               -- "NeogitTagDelete",
               "NeogitCommitComplete",
               -- "NeogitPushComplete",
               -- "NeogitPullComplete",
               -- "NeogitFetchComplete",
            },
            group = group,
            callback = function(event)
               require('neogit').close()
               -- print("Event: " .. vim.inspect(event.file))
               -- local buffername = vim.api.nvim_buf_get_name(event.buf)
               -- if buffername:match("NeogitLogView$") then
               --   vim.fn.feedkeys("q", "x") -- Close Log Graph
               --   require("neogit").open({ "log" })
               --   vim.fn.feedkeys("b", "x") -- Open log graph (branches) again    end
               -- end
            end,
         })
      end

   },
   {
      "FabijanZulj/blame.nvim",
      init = function()
         vim.keymap.set("n", "<leader>gb", "<cmd>ToggleBlame<CR>", { desc = "Neogit" })
      end
   }
}
