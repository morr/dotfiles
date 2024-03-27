-- General
vim.opt.undodir = "/tmp/nvim.undo"
vim.opt.undofile = true -- Enable persistent undo (see also `:h undodir`)

vim.opt.history = 10000
vim.opt.undolevels = 10000

vim.opt.swapfile = false -- Disable swap file

vim.opt.backup = false -- Don't store backup while overwriting the file
vim.opt.writebackup = false -- Don't store backup while overwriting the file

vim.opt.mouse = "a" -- Enable mouse for all available modes
-- vim.opt.mousemoveevent = true

vim.cmd("filetype plugin indent on") -- Enable all filetype plugins
vim.cmd("set iskeyword=@,48-57,_,192-255,$,-")
vim.cmd([[
set langmap=ё`,йq,цw,уe,кr,еt,нy,гu,шi,щo,зp,фa,ыs,вd,аf,пg,рh,оj,лk,дl,э',яz,чx,сc,мv,иb,тn,ьm,б\\,,ю.,Ё~,ЙQ,ЦW,УE,КR,ЕT,НY,ГU,ШI,ЩO,ЗP,ФA,ЫS,ВD,АF,ПG,РH,ОJ,ЛK,ДL,Ж:,Э\\",ЯZ,ЧX,СC,МV,ИB,ТN,ЬM,Б<,Ю>
]])

-- Appearance
vim.opt.cursorline = true -- Highlight current line
vim.opt.cursorlineopt = "number"
vim.opt.linebreak = true -- Wrap long lines at 'breakat' (if 'wrap' is set)
vim.opt.number = true -- Show line numbers
vim.opt.relativenumber = true
vim.opt.splitbelow = true -- Horizontal splits will be below
vim.opt.splitright = true -- Vertical splits will be to the right
vim.opt.splitkeep = "screen"

vim.opt.ruler = false -- Don't show cursor position in command line
vim.opt.showmode = false -- Don't show mode in command line
vim.opt.wrap = false -- Display long lines as just one line

vim.opt.scrolloff = 10 -- Scrolling offset

vim.opt.signcolumn = "yes" -- Always show sign column (otherwise it will shift text)
vim.opt.fillchars = "eob: " -- Don't show `~` outside of buffer

vim.opt.list = true
vim.opt.listchars = "tab:>·,trail:·,precedes:#,extends:#,nbsp:·"

-- Timings
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300

-- Editing
vim.opt.ignorecase = true -- Ignore case when searching (use `\C` to force not doing that)
vim.opt.incsearch = true -- Show search results while typing
vim.opt.infercase = true -- Infer letter cases for a richer built-in keyword completion
vim.opt.smartcase = true -- Don't ignore case when searching if pattern has upper case
vim.opt.autoindent = true
vim.opt.copyindent = true -- copy the previous indentation on autoindenting
vim.opt.breakindent = true -- Indent wrapped lines to match line start
vim.opt.smartindent = true -- Make indenting smart

vim.opt.completeopt = "menuone,noinsert,noselect" -- Customize completions
vim.opt.virtualedit = "block" -- Allow going past the end of line in visual block mode

vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2

-- set terminal title to the name of current folder
local set_title = function()
  vim.opt.title = true
  -- vim.opt.titlestring = vim.fn.getcwd()
  vim.opt.titlestring = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

vim.api.nvim_create_autocmd("DirChanged", {
  -- buffer = bufnr,
  -- command = "let &titlestring=v:event['cwd']",
  callback = set_title,
})

set_title()
