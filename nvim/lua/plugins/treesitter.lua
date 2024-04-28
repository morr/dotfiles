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
          "pug",
          -- other
          "elixir",
          "erlang",
          "python",
          "rust",
          "sql",
          "wgsl",
        },
        highlight = { enable = true },
        indent = { enable = true },
        autotag = { enable = true },
        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = "gnn",
            node_incremental = "grn",
            scope_incremental = "grc",
            node_decremental = "grm",
          },
        },
        parser_config = {
          wgsl = {
            install_info = {
              url = "https://github.com/szebniok/tree-sitter-wgsl",
              files = { "src/parser.c" },
            },
          },
        },
        -- sass = {
        --   install_info = {
        --     url = "file:///Users/morr/.local/share/nvim/lazy/nvim-treesitter/parser", -- Use file protocol for local files
        --     files = { "scss.so" },
        --   },
        --   filetype = "sass",
        --   used_by = { "sass" },
        -- },
      })

      -- local parser_config =
      --   require("nvim-treesitter.parsers").get_parser_configs()

      vim.filetype.add({ extension = { wgsl = "wgsl" } })
      -- parser_config.wgsl = {
      --   install_info = {
      --     url = "https://github.com/szebniok/tree-sitter-wgsl",
      --     files = { "src/parser.c" },
      --   },
      -- }
      --
      -- vim.filetype.add({ extension = { sass = "scss" } })
      -- parser_config.sass = {
      --   install_info = {
      --     url = "file:///Users/morr/.local/share/nvim/lazy/nvim-treesitter/parser", -- Use file protocol for local files
      --     files = { "scss.so" },
      --   },
      --   filetype = "sass",
      --   used_by = { "sass" },
      -- }
    end,
  },
  { "nvim-treesitter/playground" },
  -- {
  --   "nvim-treesitter/nvim-treesitter-context",
  --   config = function()
  --     vim.cmd("hi TreesitterContextBottom gui=underdashed guisp=#585b70")
  --   end,
  -- },
}
