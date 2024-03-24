local function show_lsp_diagnostics()
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
    zxc = true,
  }
  vim.diagnostic.open_float(nil, diagnostic_opts)
end

local toggle_lsp_lines = function()
  local new_virtual_text = not vim.diagnostic.config().virtual_text

  vim.diagnostic.config({
    virtual_text = new_virtual_text,
    update_in_insert = false,
    virtual_lines = not new_virtual_text,
  })
end

---@diagnostic disable-next-line: lowercase-global
config_lsp_mappings = function(bufnr)
  local opts = { noremap = true, silent = true, buffer = bufnr }

  if vim.fn.has("nvim-0.10") then
    vim.lsp.inlay_hint.enable(bufnr)
  else
    vim.notify("neovim >=0.10 is required for inlay_hint feature")
  end

  require("lsp_signature").on_attach({
    bind = true, -- This is mandatory, otherwise border config won't get registered.
    handler_opts = {
      border = "rounded",
    },
  }, bufnr)
  require("lsp_lines").setup()

  vim.keymap.set(
    "n",
    "<Leader>ll",
    toggle_lsp_lines,
    { desc = "Toggle lsp_lines" }
  )

  opts.desc = "Show LSP diagnostic"
  vim.keymap.set("n", "<space>", show_lsp_diagnostics, opts) -- show definition, references

  opts.desc = "Show LSP references"
  vim.keymap.set("n", "<leader>lr", "<cmd>Telescope lsp_references<CR>", opts) -- show definition, references

  opts.desc = "Go to declaration"
  vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts) -- go to declaration

  opts.desc = "Show LSP definitions"
  vim.keymap.set("n", "<leader>ld", "<cmd>Telescope lsp_definitions<CR>", opts) -- show lsp definitions

  opts.desc = "Show LSP implementations"
  vim.keymap.set(
    "n",
    "<leader>li",
    "<cmd>Telescope lsp_implementations<CR>",
    opts
  ) -- show lsp implementations

  opts.desc = "Show LSP type definitions"
  vim.keymap.set(
    "n",
    "<leader>lt",
    "<cmd>Telescope lsp_ype_definitions<CR>",
    opts
  ) -- show lsp type definitions

  opts.desc = "See available code actions"
  vim.keymap.set({ "n", "v" }, "<leader>la", vim.lsp.buf.code_action, opts) -- see available code actions, in visual mode will apply to selection
  vim.keymap.set({ "n", "v" }, ",r", vim.lsp.buf.code_action, opts) -- see available code actions, in visual mode will apply to selection

  opts.desc = "Smart rename"
  vim.keymap.set("n", "<leader>lR", vim.lsp.buf.rename, opts) -- smart rename
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
  vim.keymap.set("n", "K", vim.lsp.buf.hover, opts) -- show documentation for what is under cursor

  -- opts.desc = "Restart LSP"
  -- vim.keymap.set("n", "<leader>rs", ":LspRestart<CR>", dotfiles-unix/opts) -- mapping to restart lsp if necessary
end
