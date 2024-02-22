return {
  {
    "terrortylor/nvim-comment",
    init = function()
      require("nvim_comment").setup({
        create_mappings = false,
      })
      vim.keymap.set(
        "n",
        ", ",
        ":CommentToggle<cr>",
        { desc = "Comment toggle" }
      )
      vim.keymap.set(
        "v",
        ", ",
        ":'<,'>CommentToggle<cr>",
        { desc = "Comment toggle" }
      )
    end,
  },
}
