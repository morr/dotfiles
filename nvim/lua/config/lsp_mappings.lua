local function show_lsp_diagnostics()
  vim.v.hlsearch = "" -- because I have default behaviour to clear search on <space>

  -- If we find a floating window, close it.
  local found_float = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    -- if vim.api.nvim_win_get_config(win).relative ~= "" then
    if win == vim.diagnostic.remember_win then
      vim.api.nvim_win_close(win, true)
      found_float = true
    end
  end

  if found_float then
    return
  end

  local diagnostic_opts = {
    focusable = true,
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
  vim.diagnostic.remember_win = vim.diagnostic.open_float(nil, diagnostic_opts)
end

local toggle_lsp_lines = function()
  local new_value = not vim.diagnostic.config().virtual_text

  vim.diagnostic.config({
    virtual_text = new_value,
    virtual_lines = not new_value,
  })
end

local toggle_update_in_insert = function()
  local new_value = not vim.diagnostic.config().update_in_insert

  vim.diagnostic.config({
    update_in_insert = new_value,
  })
end

---@diagnostic disable-next-line: lowercase-global
config_lsp_mappings = function(bufnr)
  local opts = { noremap = true, silent = true, buffer = bufnr }

  local signs = {
    { name = "DiagnosticSignError", text = "" },
    { name = "DiagnosticSignWarn", text = "" },
    { name = "DiagnosticSignHint", text = "" },
    { name = "DiagnosticSignInfo", text = "" },
  }

  for _, sign in ipairs(signs) do
    vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = "" })
  end

  local config = {
    virtual_text = true,
    virtual_lines = false,
    signs = {
      active = signs,
    },
    update_in_insert = true,
    underline = true,
    float = {
      focusable = false,
      style = "minimal",
      border = "rounded",
      source = "always",
      header = "",
      prefix = "",
    },
  }

  vim.diagnostic.config(config)

  require("lsp_signature").on_attach({
    bind = true,
    handler_opts = {
      border = "rounded",
    },
  }, bufnr)
  require("lsp_lines").setup()

  vim.keymap.set("n", "<Leader>ll", toggle_lsp_lines, { desc = "Toggle lsp_lines" })
  vim.keymap.set("n", "<Leader>lu", toggle_update_in_insert, { desc = "Toggle diagnostics update_in_insert" })

  opts.desc = "Show LSP diagnostic"
  vim.keymap.set("n", "<space>", show_lsp_diagnostics, opts)

  opts.desc = "Show LSP references"
  vim.keymap.set("n", "<leader>lr", "<cmd>Telescope lsp_references<CR>", opts)

  opts.desc = "Go to declaration"
  vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)

  opts.desc = "Show LSP definitions"
  vim.keymap.set("n", "<leader>ld", "<cmd>Telescope lsp_definitions<CR>", opts)

  opts.desc = "Show LSP implementations"
  vim.keymap.set("n", "<leader>li", "<cmd>Telescope lsp_implementations<CR>", opts)

  opts.desc = "Show LSP type definitions"
  vim.keymap.set("n", "<leader>lt", "<cmd>Telescope lsp_type_definitions<CR>", opts)

  opts.desc = "See available code actions"
  vim.keymap.set({ "n", "v" }, "<leader>la", vim.lsp.buf.code_action, opts)
  vim.keymap.set({ "n", "v" }, ",r", vim.lsp.buf.code_action, opts)
  vim.keymap.set({ "n", "v" }, "<m-A>", vim.lsp.buf.code_action, opts)

  opts.desc = "Smart rename"
  vim.keymap.set("n", "<leader>lR", vim.lsp.buf.rename, opts)
  vim.keymap.set("n", "<m-R>", vim.lsp.buf.rename, opts)
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
  vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)

  -- opts.desc = "Restart LSP"
  -- vim.keymap.set("n", "<leader>rs", ":LspRestart<CR>", dotfiles-unix/opts) -- mapping to restart lsp if necessary

  opts.desc = "LSP Format"
  vim.keymap.set("n", "<leader>lf", function()
    vim.lsp.buf.format({ async = true })
  end, opts)
  vim.keymap.set("n", "<m-F>", function()
    vim.lsp.buf.format({ async = true })
  end, opts)
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == "rust-analyzer" then
      -- Small delay to ensure server is fully ready
      vim.defer_fn(function()
        vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
      end, 100)
    end
  end,
})
