return {
  {
    "mrcjkb/rustaceanvim",
    version = "^4",
    ft = { "rust" },
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      vim.g.rustaceanvim = {
        -- Plugin configuration
        -- tools = {
        -- },
        -- LSP configuration
        server = {
          ---@diagnostic disable-next-line: unused-local
          on_attach = function(client, bufnr)
            config_lsp_mappings(bufnr)

            local opts = { noremap = true, silent = true, buffer = bufnr }

            opts.desc = "See available code actions"
            vim.keymap.set(
              { "n", "v" },
              "<leader>la",
              "<cmd>RustLsp codeAction<cr>",
              opts
            )
            vim.keymap.set(
              { "n", "v" },
              ",r",
              "<cmd>RustLsp codeAction<cr>",
              opts
            )

            vim.keymap.set("n", "J", "<cmd>RustLsp joinLines<cr>", opts)
          end,
          -- default_settings = {
          --   -- rust-analyzer language server configuration
          --   ['rust-analyzer'] = {
          --   },
          -- },
        },
        -- DAP configuration
        -- dap = {
        -- },
      }
    end,
  },
}
