return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    { "antosha417/nvim-lsp-file-operations", config = true },
    -- "mihyaeru21/nvim-lspconfig-bundler",
    {
      "whynothugo/lsp_lines.nvim",
      url = "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
    },
    "ray-x/lsp_signature.nvim",
  },
  config = function()
    local cmp_nvim_lsp = require("cmp_nvim_lsp")

    ---@diagnostic disable-next-line: unused-local
    local on_attach = function(client, bufnr)
      config_lsp_mappings(bufnr)

      -- local opts = { noremap = true, silent = true, buffer = bufnr }

      -- https://github.com/neovim/nvim-lspconfig/wiki/UI-Customization#show-line-diagnostics-automatically-in-hover-window
      -- vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
      --   buffer = bufnr,
      --   callback = function()
      --     if vim.fn.mode() == "i" then
      --       return
      --     end
      --
      --     ---@diagnostic disable-next-line: undefined-field
      --     if vim.diagnostic.config().virtual_lines then
      --       return
      --     end
      --
      --     local diagnostic_opts = {
      --       focusable = false,
      --       close_events = {
      --         "BufLeave",
      --         "CursorMoved",
      --         "InsertEnter",
      --         "FocusLost",
      --       },
      --       border = "rounded",
      --       source = "always",
      --       prefix = " ",
      --       scope = "cursor",
      --     }
      --     vim.diagnostic.open_float(nil, diagnostic_opts)
      --   end,
      -- })
    end

    -- used to enable autocompletion (assign to every lsp server config)
    local capabilities = cmp_nvim_lsp.default_capabilities()

    -- Change the Diagnostic symbols in the sign column (gutter)
    local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
    for type, icon in pairs(signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
    end

    vim.lsp.config("html", {
      capabilities = capabilities,
      on_attach = on_attach,
    })

    vim.lsp.config("cssls", {
      capabilities = capabilities,
      on_attach = on_attach,
    })

    vim.lsp.config("lua_ls", {
      capabilities = capabilities,
      on_attach = function(client, bufnr)
        on_attach(client, bufnr)
        vim.api.nvim_create_autocmd("BufWritePost", {
          buffer = bufnr,
          command = "silent! !stylua %",
        })
      end,
      settings = { -- custom settings for lua
        Lua = {
          -- make the language server recognize "vim" global
          diagnostics = {
            globals = { "vim" },
          },
          workspace = {
            -- make language server aware of runtime files
            library = {
              [vim.fn.expand("$VIMRUNTIME/lua")] = true,
              [vim.fn.stdpath("config") .. "/lua"] = true,
            },
          },
        },
      },
    })

    vim.lsp.config("wgsl_analyzer", {
      capabilities = capabilities,
      on_attach = on_attach,
    })

    vim.lsp.config("eslint", {
      capabilities = capabilities,
      on_attach = function(client, bufnr)
        on_attach(client, bufnr)
        -- autofix all correctable problems on save
        vim.api.nvim_create_autocmd("BufWritePre", {
          buffer = bufnr,
          -- command = "EslintFixAll",
          callback = function()
            local notify = vim.notify
            ---@diagnostic disable-next-line: duplicate-set-field
            vim.notify = function() end -- suppress notifications
            vim.lsp.buf.format({ async = false })
            vim.notify = notify -- restore notifications
          end,
        })
      end,
    })

    vim.lsp.config("somesass_ls", {
      capabilities = capabilities,
      on_attach = on_attach,
    })

    vim.lsp.config("rubocop", {
      capabilities = capabilities,
      on_attach = on_attach,
      -- on_attach = function(client, bufnr)
      --   on_attach(client, bufnr)
      --
      --   -- this works noticeably faster that calling external rubocop script
      --   -- this implementation completely does not lag on save
      --   vim.api.nvim_create_autocmd({ "BufWritePre" }, {
      --     buffer = bufnr,
      --     callback = function()
      --       vim.lsp.buf.format({ async = true })
      --     end,
      --   })
      -- end,
    })
    vim.lsp.enable("rubocop")

    -- require("lspconfig-bundler").setup()
    -- vim.lsp.config("solargraph", {
    --   capabilities = capabilities,
    --   on_attach = on_attach,
    --   root_dir = lspconfig.util.root_pattern("Gemfile", ".git", "."),
    --   settings = {
    --     solargraph = {
    --       completion = false,
    --       autoformat = false,
    --       formatting = true,
    --       symbols = true,
    --       definitions = true,
    --       references = true,
    --       folding = true,
    --       highlights = true,
    --       diagnostics = true,
    --       rename = true,
    --     },
    --   },
    -- })

    -- vim.lsp.config("solargraph", {
    --   capabilities = capabilities,
    --   on_attach = on_attach,
    --   -- cmd = { os.getenv( "HOME" ) .. "/.rbenv/shims/solargraph", 'stdio' },
    --   root_dir = lspconfig.util.root_pattern("Gemfile", ".git", "."),
    --   -- cmd = { 'bundle', 'exec', 'solargraph' },
    --   settings = {
    --     solargraph = {
    --       completion = false,
    --       autoformat = false,
    --       formatting = true,
    --       symbols = true,
    --       definitions = true,
    --       references = true,
    --       folding = true,
    --       highlights = true,
    --       diagnostics = true,
    --       rename = true,
    --     },
    --   },
    -- })
  end,
}
