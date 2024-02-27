return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        auto_install = true,
        ensure_installed = {
          -- https://github.com/nvim-treesitter/nvim-treesitter?tab=readme-ov-file#supported-languages
          -- vim basics
          "lua",
          "vim",
          -- general
          "comment",
          "diff",
          "vimdoc",
          "bash",
          "markdown_inline",
          -- git
          "git_rebase",
          "gitattributes",
          "gitcommit",
          "gitignore",
          -- web
          "css",
          "dockerfile",
          "graphql",
          "html",
          "javascript",
          "json",
          "markdown",
          "regex",
          "ruby",
          "scss",
          "tsx",
          "vue",
          "yaml",
          -- other
          "elixir",
          -- "erlang",
          "python",
          "rust",
          "sql",
        },
        highlight = { enable = true },
        indent = { enable = true },
        autotag = { enable = true },
      })
    end,
  },
  -- {
  --   "nvim-treesitter/nvim-treesitter-context",
  --   config = function()
  --     vim.cmd("hi TreesitterContextBottom gui=underdashed guisp=#585b70")
  --   end,
  -- },
}
