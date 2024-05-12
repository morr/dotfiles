return {
  {
    "scrooloose/nerdtree",
    init = function()
      vim.keymap.set(
        "n",
        "<leader>n",
        "<cmd>:NERDTreeToggle<CR>",
        { desc = "NERDTree Toggle" }
      )
      vim.keymap.set(
        "n",
        "<leader>N",
        "<cmd>NERDTreeFind<CR>",
        { desc = "NERDTree Find" }
      )
    end,
  },
}
