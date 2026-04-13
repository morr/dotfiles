return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup()

      vim.filetype.add({ extension = { wgsl = "wgsl" } })

      local ensure_installed = {
        -- https://github.com/nvim-treesitter/nvim-treesitter/blob/main/SUPPORTED_LANGUAGES.md
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
      }

      local installed = require("nvim-treesitter").get_installed("parsers")
      local installed_set = {}
      for _, p in ipairs(installed) do
        installed_set[p] = true
      end
      local missing = vim.tbl_filter(function(p)
        return not installed_set[p]
      end, ensure_installed)
      if #missing > 0 then
        require("nvim-treesitter").install(missing)
      end

      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          local buf = args.buf
          local lang = vim.treesitter.language.get_lang(args.match)
          if not lang then
            return
          end
          if #vim.treesitter.query.get_files(lang, "highlights") == 0 then
            return
          end
          if not pcall(vim.treesitter.start, buf, lang) then
            return
          end
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
}
