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
-- For large pastes, Neovim streams data in multiple phases (1→2→3).
-- We buffer all chunks and paste once all data arrives.
local original_paste = vim.paste
local paste_buffer = {}
local paste_mode = nil

local function append_chunk(buffer, lines)
  if #buffer > 0 and #lines > 0 then
    -- Join partial lines at chunk boundary (channel-lines format)
    buffer[#buffer] = buffer[#buffer] .. lines[1]
    for i = 2, #lines do
      table.insert(buffer, lines[i])
    end
  elseif #lines > 0 then
    vim.list_extend(buffer, lines)
  end
end

vim.paste = function(lines, phase)
  local mode = vim.fn.mode()

  if mode == "n" and phase == -1 then
    -- Single-chunk paste (small text): handle directly
    if #lines > 1 then
      vim.api.nvim_command("normal! 0")
    end
    vim.api.nvim_put(lines, "c", false, true)
    return true

  elseif mode == "n" and phase == 1 then
    -- Start of multi-chunk paste: begin buffering
    paste_buffer = {}
    vim.list_extend(paste_buffer, lines)
    paste_mode = mode
    return true

  elseif paste_mode == "n" and phase == 2 then
    -- Continue buffering
    append_chunk(paste_buffer, lines)
    return true

  elseif paste_mode == "n" and phase == 3 then
    -- End of multi-chunk paste: paste all buffered content at once
    append_chunk(paste_buffer, lines)
    if #paste_buffer > 1 then
      vim.api.nvim_command("normal! 0")
    end
    vim.api.nvim_put(paste_buffer, "c", false, true)
    paste_buffer = {}
    paste_mode = nil
    return true

  elseif mode == "v" or mode == "V" then
    if mode == "V" then
      if phase == -1 and ((#lines == 1 and not lines[1]:find("\n")) or #lines > 1) then
        table.insert(lines, "")
      end
      vim.api.nvim_command("normal! 0")
    end
    return original_paste(lines, phase)

  else
    return original_paste(lines, phase)
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
map("n", "<s-cr>", "O<Esc>")

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
local function save_special()
  vim.api.nvim_command("write")
  -- print("Saved " .. vim.api.nvim_buf_get_name(0))
  -- vim.notify("Saved")
end

map({ "v", "n", "i" }, "<M-s>", save_special, { desc = "Save file" })

-- close buffer
map("n", "<leader>w", ":bd!<cr>")
map("n", "<leader>q", ":tabclose<cr>")

local function close_special()
  local bufs = vim.fn.getbufinfo({ buflisted = 1 })

  if #bufs == 1 and bufs[1].name == "" then
    vim.cmd("qa!")
  else
    vim.cmd("bd!")
  end
end
map("n", "<m-w>", close_special)

map("n", ",v", ":e ~/.config/nvim/init.lua<CR>", { desc = "Open nvim config" })
local function clean_buffer()
  -- Trailing whitespace
  vim.cmd([[%s/\(\s\|\%u00a0\|\%u202f\|\%u2003\|\%u2002\|\%u2009\)\+$//e]])

  -- Line/paragraph separators
  vim.cmd([[%s/\%u2028/ /ge]])
  vim.cmd([[%s/\%u2029/ /ge]])

  -- Zero-width characters
  vim.cmd([[%s/\%u200b//ge]]) -- zero-width space
  vim.cmd([[%s/\%u200c//ge]]) -- zero-width non-joiner
  vim.cmd([[%s/\%u200d//ge]]) -- zero-width joiner
  vim.cmd([[%s/\%u2060//ge]]) -- word joiner
  vim.cmd([[%s/\%ufeff//ge]]) -- BOM / zero-width no-break space

  -- Special spaces → regular space
  -- vim.cmd([[%s/\%u00a0/\&nbsp;/ge]]) -- non-breaking space
  vim.cmd([[%s/\%u202f//ge]]) -- narrow no-break space
  vim.cmd([[%s/\%u2003/ /ge]]) -- em space
  vim.cmd([[%s/\%u2002/ /ge]]) -- en space
end
map("n", ",t", clean_buffer, { desc = "Remove trailing whitespaces and invisible unicode" })

map("n", ",p", function()
  local path = vim.fn.expand("%")
  vim.fn.setreg("+", path)
  vim.notify(path)
end, { desc = "Copy file path to clipboard" })
