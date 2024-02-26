return {
  { "farmergreg/vim-lastplace" },
  {
    "sbdchd/neoformat",
    config = function()
      vim.g.neoformat_try_node_exe = 1
    end,
    keys = {
      { "<Leader>fm", ":Neoformat<CR>" },
    },
  },
  { "tpope/vim-sleuth" },
  {
    "nacro90/numb.nvim",
    opts = {},
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    branch = "master",
    config = function()
      require("ibl").setup()
    end,
  },
  { "tpope/vim-speeddating" },
  {
    "tpope/vim-surround",
    event = "VeryLazy",
  },
  {
    "chrisgrieser/nvim-spider",
    lazy = true,
    keys = {
      {
        "e",
        "<cmd>lua require('spider').motion('e')<CR>",
        mode = { "n", "o", "x" },
      },
      {
        "w",
        "<cmd>lua require('spider').motion('w')<CR>",
        mode = { "n", "o", "x" },
      },
      {
        "b",
        "<cmd>lua require('spider').motion('b')<CR>",
        mode = { "n", "o", "x" },
      },
      -- russian
      {
        "у",
        "<cmd>lua require('spider').motion('e')<CR>",
        mode = { "n", "o", "x" },
      },
      {
        "ц",
        "<cmd>lua require('spider').motion('w')<CR>",
        mode = { "n", "o", "x" },
      },
      {
        "и",
        "<cmd>lua require('spider').motion('b')<CR>",
        mode = { "n", "o", "x" },
      },
    },
    init = function()
      require("spider").setup({
        skipInsignificantPunctuation = false, -- this is essential to make it to not skip russian words
        subwordMovement = true,
      })
    end,
  },
}
