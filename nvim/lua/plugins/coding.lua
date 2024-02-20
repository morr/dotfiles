return {
   { "farmergreg/vim-lastplace", },
   {
      "sbdchd/neoformat",
      config = function()
         vim.g.neoformat_try_node_exe = 1
      end,
      keys = {
         { "<Leader>fm", ":Neoformat<CR>" },
      },
   },
   { "tpope/vim-sleuth", },
   {
      "nacro90/numb.nvim",
      opts = {},
   },
   {
      "terrortylor/nvim-comment",
      init = function()
         require('nvim_comment').setup({       
            create_mappings = false
         })
         vim.keymap.set("n", ", ", ":CommentToggle<cr>", {})
         vim.keymap.set("v", ", ", ":'<,'>CommentToggle<cr>", {})
      end
   },
   {
      "norcalli/nvim-colorizer.lua",
      config = function()
         require("colorizer").setup()
      end,
   },
   {
      "lukas-reineke/indent-blankline.nvim",
      branch = "master",
      config = function()
         require("ibl").setup()
      end,
   },
   { "tpope/vim-speeddating", },
   {
      "kylechui/nvim-surround",
      event = "VeryLazy",
      -- opts = {
      --    keymaps = {
      --       normal = "gs",
      --       normal_cur = "gss",
      --    },
      -- },
   },
   {
      "chrisgrieser/nvim-spider",
      keys = {
         { "e", "<cmd>lua require('spider').motion('e')<CR>", mode = { "n", "o", "x" }, },
         { "w", "<cmd>lua require('spider').motion('w')<CR>", mode = { "n", "o", "x" }, },
         { "b", "<cmd>lua require('spider').motion('b')<CR>", mode = { "n", "o", "x" }, },
         -- russian
         { "у", "<cmd>lua require('spider').motion('e')<CR>", mode = { "n", "o", "x" }, },
         { "ц", "<cmd>lua require('spider').motion('w')<CR>", mode = { "n", "o", "x" }, },
         { "и", "<cmd>lua require('spider').motion('b')<CR>", mode = { "n", "o", "x" }, },
      }
   }
}
