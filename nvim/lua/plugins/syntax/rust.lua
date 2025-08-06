return {
  {
    "mrcjkb/rustaceanvim",
    ft = { "rust" },
    dependencies = { "mfussenegger/nvim-dap" },
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
