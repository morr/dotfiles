-- disable netrw at the very start of your init.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

return {
   {
      "nvim-tree/nvim-tree.lua",
      config = function()
        require("nvim-tree").setup({
            filters = {
                dotfiles = true,
            }
        })

        -- local api = require "nvim-tree.api"
        -- vim.keymap.set('n', '<leader>n', api.tree.toggle)
        vim.keymap.set('n', '<leader>n', ':NvimTreeToggle<cr>')
        vim.keymap.set('n', '<leader>N', ':NvimTreeFindFileToggle<cr>')
      end,
      dependencies = { 'nvim-tree/nvim-web-devicons' },
   }
}
