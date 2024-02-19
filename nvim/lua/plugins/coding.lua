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
         require('nvim_comment').setup()
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
      version = "*",
      event = "VeryLazy",
      opts = {
         keymaps = {
            normal = "gs",
            normal_cur = "gss",
         },
      },
   },
}
