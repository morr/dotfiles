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
    local lspconfig = require("lspconfig")
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

    -- require("lspconfig-bundler").setup()
    -- lspconfig["solargraph"].setup({
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

    lspconfig["wgsl_analyzer"].setup({
      capabilities = capabilities,
      on_attach = on_attach,
    })

    vim.g.rustaceanvim = {
      server = {
        ---@diagnostic disable-next-line: unused-local
        on_attach = function(client, bufnr)
          config_lsp_mappings(bufnr)

          local opts = { noremap = true, silent = true, buffer = bufnr }

          opts.desc = "See available code actions"
          vim.keymap.set({ "n", "v" }, "<leader>la", "<cmd>RustLsp codeAction<cr>", opts)
          -- vim.keymap.set(
          --   { "n", "v" },
          --   ",a",
          --   "<cmd>RustLsp codeAction<cr>",
          --   opts
          -- )
          -- vim.keymap.set(
          --   { "n", "v" },
          --   "<M-R>",
          --   "<cmd>RustLsp codeAction<cr>",
          --   opts
          -- )
          vim.keymap.set({ "n", "v" }, "<M-A>", "<cmd>RustLsp codeAction<cr>", opts)
          vim.keymap.set({ "n", "v" }, "<c-s-a>", "<cmd>RustLsp codeAction<cr>", opts)

          vim.keymap.set("n", "J", "<cmd>RustLsp joinLines<cr>", opts)

          opts.desc = "cargo run"
          vim.keymap.set(
            { "n", "i" },
            ",cR",
            "<cmd>TermExec cmd='cargo run'<cr>",
            -- "<cmd>TermExec cmd='MTL_HUD_ENABLED=1 cargo run'<cr>",
            opts
          )
          opts.desc = "cargo run and exit"
          vim.keymap.set(
            { "n", "i" },
            ",cr",
            "<cmd>TermExec cmd='cargo run; exit'<cr>",
            -- "<cmd>TermExec cmd='MTL_HUD_ENABLED=1 cargo run; exit'<cr>",
            opts
          )

          opts.desc = "cargo build"
          vim.keymap.set({ "n", "i" }, ",cb", "<cmd>TermExec cmd='cargo build'<cr>", opts)

          opts.desc = "cargo test"
          vim.keymap.set({ "n", "i" }, ",cT", "<cmd>TermExec cmd='cargo test'<cr>", opts)

          opts.desc = "Neotest: run nearest test"
          vim.keymap.set({ "n", "i" }, "<m-T>", function()
            require("neotest").run.run()
          end, opts)
        end,
      },
      tools = {
        float_win_config = {
          border = "rounded",
        },
      },
    }

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
  end,
}
