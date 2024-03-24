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
          on_attach = function(client, bufnr)
            local opts = { noremap = true, silent = true, buffer = bufnr }

            if vim.fn.has("nvim-0.10") then
              vim.lsp.inlay_hint.enable(bufnr)
            else
              vim.notify("neovim >=0.10 is required for inlay_hint feature")
            end

            require("lsp_signature").on_attach({
              bind = true, -- This is mandatory, otherwise border config won't get registered.
              handler_opts = {
                border = "rounded",
              },
            }, bufnr)

            --- START copied from lspconfig
            opts.desc = "Show LSP references"
            vim.keymap.set(
              "n",
              "<leader>lr",
              "<cmd>Telescope lsp_references<CR>",
              opts
            ) -- show definition, references

            opts.desc = "Go to declaration"
            vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts) -- go to declaration

            opts.desc = "Show LSP definitions"
            vim.keymap.set(
              "n",
              "<leader>ld",
              "<cmd>Telescope lsp_definitions<CR>",
              opts
            ) -- show lsp definitions

            opts.desc = "Show LSP implementations"
            vim.keymap.set(
              "n",
              "<leader>li",
              "<cmd>Telescope lsp_implementations<CR>",
              opts
            ) -- show lsp implementations

            opts.desc = "Show LSP type definitions"
            vim.keymap.set(
              "n",
              "<leader>lt",
              "<cmd>Telescope lsp_ype_definitions<CR>",
              opts
            ) -- show lsp type definitions

            opts.desc = "See available code actions"
            vim.keymap.set(
              { "n", "v" },
              "<leader>la",
              vim.lsp.buf.code_action,
              opts
            ) -- see available code actions, in visual mode will apply to selection
            vim.keymap.set({ "n", "v" }, ",r", vim.lsp.buf.code_action, opts) -- see available code actions, in visual mode will apply to selection

            opts.desc = "Smart rename"
            vim.keymap.set("n", "<leader>lR", vim.lsp.buf.rename, opts) -- smart rename
            --
            -- opts.desc = "Show buffer diagnostics"
            -- vim.keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts) -- show  diagnostics for file
            --
            -- opts.desc = "Show line diagnostics"
            -- vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts) -- show diagnostics for line
            --
            -- opts.desc = "Go to previous diagnostic"
            -- vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts) -- jump to previous diagnostic in buffer
            --
            -- opts.desc = "Go to next diagnostic"
            -- vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts) -- jump to next diagnostic in buffer

            opts.desc = "Show documentation for what is under cursor"
            vim.keymap.set("n", "K", vim.lsp.buf.hover, opts) -- show documentation for what is under cursor

            -- opts.desc = "Restart LSP"
            -- vim.keymap.set("n", "<leader>rs", ":LspRestart<CR>", dotfiles-unix/opts) -- mapping to restart lsp if necessary
            --- END copied from lspconfig ---

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
