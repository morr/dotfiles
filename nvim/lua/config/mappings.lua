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

-- <M-c> is a keyboard shortcut in iterm2
-- https://github.com/neovim/neovim/issues/5052#issuecomment-232083842
-- Keyboard Shortcut: ⌘c
-- Action: Send Escape Sequence
-- Esc+: c

-- Cut
map({ "v", "n" }, "<M-x>", '"+x')

-- Copy
map({ "v", "n" }, "<M-c>", '"+y')

-- Paste
--map({ "v", "n" }, "<M-v>", '"+gP')
--map("i", "<M-v>", '<c-r>+')

map("v", "<", "<gv")
map("v", ">", ">gv")

-- insert newline after current line
map("n", "<cr>", "o<Esc>")

-- insert newline before current line
map("n", "<s-cr>", "O<Esc>")

-- turn off highlighting and clear messages
map("n", "<space>", ":nohlsearch<Bar>:echo<cr>")

-- select all
map("n", "<c-a>", "ggVG")

-- sort selection
map("v", "<c-s>", ":sor<cr>")

-- save
map("n", "<M-s>", ":w<cr>")
map("i", "<M-s>", "<esc>:w<cr>a")
map("v", "<M-s>", "<esc>:w<cr>")

-- close buffer
map("n", "<leader>w", ":bd<cr>")
map("n", "<leader>q", ":tabclose<cr>")

-- open nvim config
map("n", ",v", ":e ~/.config/nvim/init.lua<CR>")

-- window movements
--map("n", "<C-k>", "<C-w>k", {})
--map("n", "<C-j>", "<C-w>j", {})
--map("n", "<C-h>", "<C-w>h", {})
--map("n", "<C-l>", "<C-w>l", {})
--map("n", "<C-c>", "<C-w>c", {})
