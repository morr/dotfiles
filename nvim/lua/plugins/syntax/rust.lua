return {
  {
    "mrcjkb/rustaceanvim",
    version = '^6', -- Recommended
    ft = { "rust" },
    dependencies = { "mfussenegger/nvim-dap" },
    lazy = false,
    config = function()
      -- neotest intergration
      require("neotest").setup({
        adapters = {
          require("rustaceanvim.neotest"),
        },
      })
    end,
  },
}
