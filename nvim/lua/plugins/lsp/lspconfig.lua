local toggle_lsp_lines = function()
  local new_virtual_text = not vim.diagnostic.config().virtual_text

  vim.diagnostic.config({
    virtual_text = new_virtual_text,
    update_in_insert = false,
    virtual_lines = not new_virtual_text,
  })
end

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

    local keymap = vim.keymap -- for conciseness
    local opts = { noremap = true, silent = true }

    ---@diagnostic disable-next-line: unused-local
    local on_attach = function(client, bufnr)
      opts.buffer = bufnr

      if vim.fn.has("nvim-0.10") then
        vim.lsp.inlay_hint.enable(bufnr)
      else
        vim.notify("neovim >=0.10 is required for inlay_hint feature")
      end

      require("lsp_lines").setup()

      vim.diagnostic.config({
        virtual_text = true,
        update_in_insert = false,
        virtual_lines = false,
      })

      require("lsp_signature").on_attach({
        bind = true, -- This is mandatory, otherwise border config won't get registered.
        handler_opts = {
          border = "rounded",
        },
      }, bufnr)

      -- https://github.com/neovim/nvim-lspconfig/wiki/UI-Customization#show-line-diagnostics-automatically-in-hover-window
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        buffer = bufnr,
        callback = function()
          if vim.fn.mode() == "i" then
            return
          end

          ---@diagnostic disable-next-line: undefined-field
          if vim.diagnostic.config().virtual_lines then
            return
          end

          local diagnostic_opts = {
            focusable = false,
            close_events = {
              "BufLeave",
              "CursorMoved",
              "InsertEnter",
              "FocusLost",
            },
            border = "rounded",
            source = "always",
            prefix = " ",
            scope = "cursor",
          }
          vim.diagnostic.open_float(nil, diagnostic_opts)
        end,
      })

      -- require("which-key").register({
      --   ["<leader>"] = {
      --     l = {
      --       name = "LSP",
      --     },
      --   },
      -- })

      opts.desc = "Show LSP references"
      keymap.set("n", "<leader>lr", "<cmd>Telescope lsp_references<CR>", opts) -- show definition, references

      opts.desc = "Go to declaration"
      keymap.set("n", "gD", vim.lsp.buf.declaration, opts) -- go to declaration

      opts.desc = "Show LSP definitions"
      keymap.set("n", "<leader>ld", "<cmd>Telescope lsp_definitions<CR>", opts) -- show lsp definitions

      opts.desc = "Show LSP implementations"
      keymap.set(
        "n",
        "<leader>li",
        "<cmd>Telescope lsp_implementations<CR>",
        opts
      ) -- show lsp implementations

      opts.desc = "Show LSP type definitions"
      keymap.set(
        "n",
        "<leader>lt",
        "<cmd>Telescope lsp_type_definitions<CR>",
        opts
      ) -- show lsp type definitions

      opts.desc = "See available code actions"
      keymap.set({ "n", "v" }, "<leader>la", vim.lsp.buf.code_action, opts) -- see available code actions, in visual mode will apply to selection
      keymap.set({ "n", "v" }, ",r", vim.lsp.buf.code_action, opts) -- see available code actions, in visual mode will apply to selection

      opts.desc = "Smart rename"
      keymap.set("n", "<leader>lR", vim.lsp.buf.rename, opts) -- smart rename
      --
      -- opts.desc = "Show buffer diagnostics"
      -- keymap.set("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<CR>", opts) -- show  diagnostics for file
      --
      -- opts.desc = "Show line diagnostics"
      -- keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts) -- show diagnostics for line
      --
      -- opts.desc = "Go to previous diagnostic"
      -- keymap.set("n", "[d", vim.diagnostic.goto_prev, opts) -- jump to previous diagnostic in buffer
      --
      -- opts.desc = "Go to next diagnostic"
      -- keymap.set("n", "]d", vim.diagnostic.goto_next, opts) -- jump to next diagnostic in buffer

      opts.desc = "Show documentation for what is under cursor"
      keymap.set("n", "K", vim.lsp.buf.hover, opts) -- show documentation for what is under cursor

      -- opts.desc = "Restart LSP"
      -- keymap.set("n", "<leader>rs", ":LspRestart<CR>", dotfiles-unix/opts) -- mapping to restart lsp if necessary

      keymap.set(
        "n",
        "<Leader>ll",
        toggle_lsp_lines,
        { desc = "Toggle lsp_lines" }
      )
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

    lspconfig["rubocop"].setup({
      capabilities = capabilities,
      -- on_attach = on_attach,
      on_attach = function(client, bufnr)
        on_attach(client, bufnr)

        -- this works nnoticeably faster that calling external rubocop script
        -- this implementation completely does not lag on save
        vim.api.nvim_create_autocmd({ "BufWritePre" }, {
          buffer = bufnr,
          callback = function()
            vim.lsp.buf.format({ async = true })
          end,
        })
      end,
    })

    -- ruby server
    require("lspconfig-bundler").setup()
    lspconfig["solargraph"].setup({
      capabilities = capabilities,
      on_attach = on_attach,
      -- cmd = { os.getenv( "HOME" ) .. "/.rbenv/shims/solargraph", 'stdio' },
      root_dir = lspconfig.util.root_pattern("Gemfile", ".git", "."),
      -- cmd = { 'bundle', 'exec', 'solargraph' },
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

    lspconfig["rust_analyzer"].setup({
      settings = {
        rust_analyzer = {
          diagnostics = {
            enable = true,
          },
          cargo = {
            allFeatures = true,
          },
        },
      },
      root_dit = lspconfig.util.root_pattern("Cargo.toml"),

      capabilities = capabilities,
      -- on_attach = on_attach,
      on_attach = function(client, bufnr)
        on_attach(client, bufnr)

        -- `brew install rustfmt`
        vim.api.nvim_create_autocmd({ "BufWritePre" }, {
          buffer = bufnr,
          callback = function()
            vim.lsp.buf.format({ async = true })
          end,
        })

        keymap.set(
          { "n", "i" },
          "<leader>R",
          "<cmd>TermExec cmd='MTL_HUD_ENABLED=1 cargo run'<cr>",
          { buffer = bufnr }
        )
        keymap.set(
          { "n", "i" },
          "<leader>r",
          "<cmd>TermExec cmd='MTL_HUD_ENABLED=1 cargo run; exit'<cr>",
          { buffer = bufnr }
        )
      end,
    })
  end,
}
