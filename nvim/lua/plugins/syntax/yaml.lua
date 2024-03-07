return {
  {
    "cuducos/yaml.nvim",
    ft = { "yaml", "yml" }, -- optional
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-telescope/telescope.nvim", -- optional
    },
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "eruby.yaml",
        callback = function()
          vim.bo.filetype = "yaml"
        end,
      })
      -- vim.filetype.add({ extensions = { yml = "yaml" } })
      -- au BufNewFile,BufRead *.json set filetype=json
    end,
  },
}
