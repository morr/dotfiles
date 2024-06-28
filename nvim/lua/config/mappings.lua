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

-- map({ "v", "n" }, "<c-v>", '"*p')  -- Paste from clipboard
-- map("i", "<c-v>", '<c-r>*')  -- Paste from clipboard in insert mode

-- Custom paste implementation that pastes text BEFORE cursor in normal mode
local original_paste = vim.paste
-- Explanation
-- Mode Check: The function now explicitly checks for being in normal mode (vim.fn.mode() == "n") to apply the custom behavior.
-- Phase Check: Ensures that the custom pasting logic only applies during the first phase of pasting (phase == 1). Pasting can be a multi-phase operation especially with clipboard managers or when triggered by external scripts, so this ensures we only modify the initial insertion behavior.
-- Using vim.api.nvim_put: This function is used to put the lines into the buffer. The parameters are adjusted to not advance the cursor unnecessarily:
-- The second parameter 'c' tells Neovim to treat the lines as if they were yanked into a register, keeping the block structure if it's a block-wise visual mode yank.
-- The third parameter false ensures we are not advancing the cursor after the paste.
-- The fourth parameter true sets the paste as a normal command, which, in normal mode, means it follows the normal mode cursor behavior (i.e., paste after the cursor).
vim.paste = function(lines, phase)
  local mode = vim.fn.mode()
  -- Check if we are in normal mode (`n`), and phase is the first phase of pasting (`1`)
  vim.notify("Paste mode: " .. mode .. ", lines: " .. vim.inspect(lines) .. ", phase: " .. phase)

  if mode == "n" and (phase == 1 or phase == -1) then
    -- If the content has more than one line, paste at the beginning of the current line
    if #lines > 1 then
      vim.api.nvim_command("normal! 0")
    end
    -- Use `p` for normal mode to paste after the cursor
    vim.api.nvim_put(lines, "c", false, true)
  elseif mode == "v" or mode == "V" then
    -- add newline if content has no \n
    if mode == "V" then
      if #lines == 1 and not lines[1]:find("\n") then
        table.insert(lines, "")
      end

      -- For visual line-wise mode, move cursor to the start of the line
      vim.api.nvim_command("normal! 0")
    end

    original_paste(lines, phase)
  else
    original_paste(lines, phase)
  end
end

-- prevent yanking into register empty line
local function delete_special()
  local line_data = vim.api.nvim_win_get_cursor(0) -- returns {row, col}
  local current_line = vim.api.nvim_buf_get_lines(0, line_data[1] - 1, line_data[1], false)
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

-- compensates for insert mode <shift-space> => <m-r> mapping in iterm2
map("i", "<m-r>", "<space>")

-- save
map({ "v", "n", "i" }, "<M-s>", function()
  vim.api.nvim_command("write")
  -- print("Saved " .. vim.api.nvim_buf_get_name(0))
  -- vim.notify("Saved")
end, { desc = "Save file" })

-- close buffer
map("n", "<leader>w", ":bd!<cr>")
map("n", "<leader>q", ":tabclose<cr>")
-- map("n", "<m-w>", ":bd!<cr>")
map("n", "<m-w>", function()
  local bufs = vim.fn.getbufinfo({ buflisted = 1 })

  if #bufs == 1 and bufs[1].name == "" then
    vim.cmd("qa!")
  else
    vim.cmd("bd!")
  end
end)

map("n", ",v", ":e ~/.config/nvim/init.lua<CR>", { desc = "Open nvim config" })
map("n", ",t", [[:%s/\s\+$//e<cr>]], { desc = "Remove trailing whitespaces" })
