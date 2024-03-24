return {
  "williamboman/mason.nvim",
  dependencies = {
    {
      "williamboman/mason-lspconfig.nvim",
      -- using this fork until PR is merged https://github.com/williamboman/mason-lspconfig.nvim/pull/372
      url = "https://github.com/simeonoff/mason-lspconfig.nvim.git",
      branch = "somesass_ls",
    },
    "WhoIsSethDaniel/mason-tool-installer.nvim",
  },
  config = function()
    local mason = require("mason")
    local mason_lspconfig = require("mason-lspconfig")
    local mason_tool_installer = require("mason-tool-installer")

    -- enable mason and configure icons
    mason.setup({
      ui = {
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    })

    mason_lspconfig.setup({
      -- list of servers for mason to install
      ensure_installed = {
        "html",
        "cssls",
        "eslint",
        "lua_ls",
        "rust_analyzer",
        "somesass_ls",
        -- "solargraph", -- auto install does not work. each project needs own solargraph gem installed
      },
      -- auto-install configured servers (with lspconfig)
      automatic_installation = true, -- not the same as ensure_installed
    })

    mason_tool_installer.setup({
      ensure_installed = {
        -- "prettier", -- prettier formatter
        "stylua", -- lua formatter
        "eslint_d", -- js linter
        "codelldb",
      },
    })
  end,
}
