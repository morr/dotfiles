return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    { "antosha417/nvim-lsp-file-operations", config = true },
    "mihyaeru21/nvim-lspconfig-bundler",
    {
      "whynothugo/lsp_lines.nvim",
      url = "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
    },
    "ray-x/lsp_signature.nvim",
  },
  config = function()
    local lspconfig = require("lspconfig")
    local cmp_nvim_lsp = require("cmp_nvim_lsp")

    ---@diagnostic disable-next-line: unused-local
    local on_attach = function(client, bufnr)
      config_lsp_mappings(bufnr)

      -- local opts = { noremap = true, silent = true, buffer = bufnr }

      vim.diagnostic.config({
        virtual_text = true,
        update_in_insert = false,
        virtual_lines = false,
      })

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
    local signs =
      { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
    for type, icon in pairs(signs) do
      local hl = "DiagnosticSign" .. type
      vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
    end

    lspconfig["html"].setup({
      capabilities = capabilities,
      on_attach = on_attach,
    })

    lspconfig["cssls"].setup({
      capabilities = capabilities,
      on_attach = on_attach,
    })

    lspconfig["lua_ls"].setup({
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

    lspconfig["eslint"].setup({
      capabilities = capabilities,
      on_attach = function(client, bufnr)
        on_attach(client, bufnr)
        -- autofix all correctable problems on save
        vim.api.nvim_create_autocmd("BufWritePre", {
          buffer = bufnr,
          command = "EslintFixAll",
        })
      end,
    })

    lspconfig["somesass_ls"].setup({
      capabilities = capabilities,
      on_attach = on_attach,
    })

    -- Check if solargraph is available in the project context
    local handle = io.popen("bundle exec which rubocop")
    local result = handle:read("*a")
    handle:close()

    if result ~= "" then
      lspconfig["rubocop"].setup({
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
    end

    -- ruby server

    -- Attempt to get help from solargraph, which should be harmless
    local handle = io.popen("bundle exec solargraph help 2>&1")
    local result = handle:read("*a")
    handle:close()

    -- Check for success indicator, typically the absence of a specific error message
    if
      not string.match(result, "command not found")
      and not string.match(result, "No such command")
    then
      require("lspconfig-bundler").setup()
      lspconfig["solargraph"].setup({
        capabilities = capabilities,
        on_attach = on_attach,
        root_dir = lspconfig.util.root_pattern("Gemfile", ".git", "."),
        settings = {
          solargraph = {
            completion = false,
            autoformat = false,
            formatting = true,
            symbols = true,
            definitions = true,
            references = true,
            folding = true,
            highlights = true,
            diagnostics = true,
            rename = true,
          },
        },
      })
    end

    -- lspconfig["solargraph"].setup({
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

    -- lspconfig["rust_analyzer"].setup({
    --   settings = {
    --     rust_analyzer = {
    --       diagnostics = {
    --         enable = true,
    --       },
    --       cargo = {
    --         allFeatures = true,
    --       },
    --     },
    --   },
    --   root_dit = lspconfig.util.root_pattern("Cargo.toml"),
    --
    --   capabilities = capabilities,
    --   -- on_attach = on_attach,
    --   on_attach = function(client, bufnr)
    --     on_attach(client, bufnr)
    --
    --     -- `brew install rustfmt`
    --     vim.api.nvim_create_autocmd({ "BufWritePre" }, {
    --       buffer = bufnr,
    --       callback = function()
    --         vim.lsp.buf.format({ async = true })
    --       end,
    --     })
    --
    --     keymap.set(
    --       { "n", "i" },
    --       "<leader>R",
    --       "<cmd>TermExec cmd='MTL_HUD_ENABLED=1 cargo run'<cr>",
    --       { buffer = bufnr }
    --     )
    --     keymap.set(
    --       { "n", "i" },
    --       "<leader>r",
    --       "<cmd>TermExec cmd='MTL_HUD_ENABLED=1 cargo run; exit'<cr>",
    --       { buffer = bufnr }
    --     )
    --   end,
    -- })

    lspconfig["wgsl_analyzer"].setup({
      capabilities = capabilities,
      on_attach = on_attach,
    })
  end,
}
