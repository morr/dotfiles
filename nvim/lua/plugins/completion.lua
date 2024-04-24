return {
  {
    "hrsh7th/nvim-cmp",
    -- event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-nvim-lua",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "hrsh7th/cmp-buffer",
      -- "hrsh7th/cmp-nvim-lsp-signature-help",
      -- "hrsh7th/cmp-omni",
      "onsails/lspkind.nvim",
    },
    config = function()
      local lspkind = require("lspkind")
      local cmp = require("cmp")

      local has_words_before = function()
        unpack = unpack or table.unpack
        local line, col = unpack(vim.api.nvim_win_get_cursor(0))
        return col ~= 0
          and vim.api
              .nvim_buf_get_lines(0, line - 1, line, true)[1]
              :sub(col, col)
              :match("%s")
            == nil
      end

      cmp.setup({
        preselect = "none",
        -- completion = {
        --    completeopt = "menu,menuone,preview,noselect",
        -- },
        -- do not use preset mappings since they conflict with <c-n>/<c-p> in telecope
        -- mapping = cmp.mapping.preset.insert({
        --    ["<C-k>"] = cmp.mapping.select_prev_item(), -- previous suggestion
        --    ["<C-j>"] = cmp.mapping.select_next_item(), -- next suggestion
        --    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        --    ["<C-f>"] = cmp.mapping.scroll_docs(4),
        --    -- ["<C-Space>"] = cmp.mapping.complete(), -- show completion suggestions
        --    ["<C-e>"] = cmp.mapping.abort(), -- close completion window
        --    -- ["<C-c>"] = cmp.mapping.abort(), -- close completion window
        --    -- ["<ESC>"] = cmp.mapping.abort(), -- close completion window
        --    ["<CR>"] = cmp.mapping.confirm({ select = false }),
        --    -- -- ["<C-b>"] = cmp.mapping.scroll_docs(-4),
        --    -- -- ["<C-f>"] = cmp.mapping.scroll_docs(4),
        --    -- ["<CR>"] = cmp.mapping.confirm({ select = true }),
        --    -- ["<Tab>"] = cmp.mapping.select_next_item(),
        --    -- ["<S-Tab>"] = cmp.mapping.select_prev_item(),
        -- },
        mapping = {
          ["<C-p>"] = cmp.mapping.select_prev_item({
            behavior = cmp.SelectBehavior.Select,
          }),
          ["<C-n>"] = cmp.mapping.select_next_item({
            behavior = cmp.SelectBehavior.Select,
          }),
          ["<C-d>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          -- ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.close(),
          ["<CR>"] = cmp.mapping.confirm({
            behavior = cmp.ConfirmBehavior.Replace,
            select = true,
          }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
            elseif has_words_before() then
              cmp.complete()
            else
              fallback()
            end
          end, { "i", "s" }),
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        sources = cmp.config.sources({
          -- { name = "nvim_lsp_signature_help" }, -- displaying function signatures with the current parameter emphasized
          { name = "nvim_lsp" },
          { name = "nvim_lua" },
          {
            name = "buffer",
            option = {
              get_bufnrs = function()
                return vim.api.nvim_list_bufs()
              end,
            },
          },
          -- { name = "omni" },
          { name = "path" },
        }),
        enabled = function()
          -- disable completion in comments
          local context = require("cmp.config.context")

          -- disable completion in telescope
          local buftype = vim.api.nvim_buf_get_option(0, "buftype")
          if buftype == "prompt" then
            return false
          end

          -- keep command mode completion enabled
          if vim.api.nvim_get_mode().mode == "c" then
            return true
          else
            return not context.in_treesitter_capture("comment")
              and not context.in_syntax_group("Comment")
          end
        end,
        formatting = {
          format = lspkind.cmp_format({
            mode = "symbol_text",
            maxwidth = 50,
            ellipsis_char = "...",
            menu = {
              buffer = "[Buffer]",
              nvim_lsp = "[LSP]",
              nvim_lua = "[Lua]",
            },
          }),
        },
      })

      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = "buffer" },
        },
      })

      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources(
          { { name = "path" } },
          { { name = "cmdline" } }
        ),
      })
    end,
  },
}
