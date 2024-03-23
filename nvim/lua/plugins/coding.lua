return {
  {
    -- renders identation lines
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {},
    init = function()
      require("ibl").setup()
    end,
  },
  {
    -- A vim / nvim plugin that intelligently reopens files at your last edit position.
    "farmergreg/vim-lastplace",
  },
  {
    -- A (Neo)vim plugin for formatting code.
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
    -- allows <c-a> / <c-x> to properly increment dates
    "tpope/vim-speeddating",
  },
  {
    "tpope/vim-surround",
    event = "VeryLazy",
  },
  {
    "tpope/vim-abolish",
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
