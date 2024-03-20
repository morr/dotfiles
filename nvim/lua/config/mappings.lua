local function map(mode, lhs, rhs, opts)
  if opts == nil then
    opts = {}
  end
  -- set default value if not specify
  if opts.noremap == nil then
    opts.noremap = true
  end
  if opts.silent == nil then
    opts.silent = true
  end

  vim.keymap.set(mode, lhs, rhs, opts)
end

vim.g.mapleader = "\\"
vim.g.maplocalleader = "\\"

--
-- Movement
--

map({ "v", "n" }, "<c-k>", "10k")
map({ "v", "n" }, "<c-j>", "10j")

-- up
map({ "v", "n" }, "k", "gk")
map({ "i", "c" }, "<c-k>", "<up>")

-- down
map({ "v", "n" }, "j", "gj")
map({ "i", "c" }, "<c-j>", "<down>")

-- left
map({ "v", "n" }, "h", "<left>")
map({ "i", "c" }, "<c-h>", "<left>")

-- right
map({ "v", "n" }, "l", "<right>")
map({ "i", "c" }, "<c-l>", "<right>")

-- normal <c-c> in insert mode does not trigger InsertLeave event
-- which leads to lsp diagnostics not being updated
map({ "i" }, "<c-c>", "<esc>")

-- <M-c> is a keyboard shortcut in iterm2
-- https://github.com/neovim/neovim/issues/5052#issuecomment-232083842
-- Keyboard Shortcut: ⌘c
-- Action: Send Escape Sequence
-- Esc+: c

-- Cut
map({ "v", "n" }, "<M-x>", '"*x')

-- Copy
map({ "v", "n" }, "<M-c>", '"*y')

-- Paste
-- map({ "v", "n" }, "<M-v>", '"*gP')
-- map("i", "<M-v>", '<c-r>+')

-- Custom paste implementation that pastes text BEFORE cursor
local original_paste = vim.paste
-- https://github.com/neovim/neovim/blob/master/runtime/lua/vim/_editor.lua#L236C29-L236C34
vim.paste = function(lines, phase) -- custom paste function to insert text before cursor
  if vim.fn.mode() == "n" then
    vim.api.nvim_put(lines, "c", false, true)
  else
    original_paste(lines, phase)
  end
end

-- prevent yanking into register empty line
local function delete_special()
  local line_data = vim.api.nvim_win_get_cursor(0) -- returns {row, col}
  local current_line =
    vim.api.nvim_buf_get_lines(0, line_data[1] - 1, line_data[1], false)
  if current_line[1] == "" then
    return '"_dd'
  else
    return "dd"
  end
end
map("n", "dd", delete_special, { noremap = true, expr = true })

map("v", "<", "<gv")
map("v", ">", ">gv")

-- insert newline after current line
map("n", "<cr>", "o<Esc>")

-- insert newline before current line
map("n", "<m-\\>", "O<Esc>")

-- turn off highlighting and clear messages
map("n", "<space>", ":nohlsearch<Bar>:echo<cr>")

-- select all
map("n", "<m-a>", "ggVG")

-- sort selection
map("v", "<c-s>", ":sor<cr>")

-- quickfix
map("n", "q]", "<cmd>cn<cr>")
map("n", "q[", "<cmd>cp<cr>")
map("n", "q<backspace>", "<cmd>call setqflist([])<cr>")

-- save
map({ "v", "n", "i" }, "<M-s>", function()
  vim.api.nvim_command("write")
  -- print("Saved " .. vim.api.nvim_buf_get_name(0))
  -- vim.notify("Saved")
end, { desc = "Save file" })

-- close buffer
map("n", "<leader>w", ":bd<cr>")
map("n", "<leader>q", ":tabclose<cr>")

map("n", ",v", ":e ~/.config/nvim/init.lua<CR>", { desc = "Open nvim config" })
map("n", ",t", [[:%s/\s\+$//e<cr>]], { desc = "Remove trailing whitespaces" })
