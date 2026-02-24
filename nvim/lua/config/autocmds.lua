-- Auto-reload files changed outside of Neovim
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
   command = "silent! checktime",
})

-- Rubocop diagnostics for slim files (rubocop --lsp doesn't support slim)
local rubocop_slim_ns = vim.api.nvim_create_namespace("rubocop_slim")
local severity_map = {
   convention = vim.diagnostic.severity.HINT,
   refactor = vim.diagnostic.severity.HINT,
   warning = vim.diagnostic.severity.WARN,
   error = vim.diagnostic.severity.ERROR,
   fatal = vim.diagnostic.severity.ERROR,
}

local function rubocop_slim_lint(bufnr)
   local filepath = vim.api.nvim_buf_get_name(bufnr)
   if filepath == "" then
      return
   end

   vim.fn.jobstart({ "rubocop", "--format", "json", "--no-color", filepath }, {
      stdout_buffered = true,
      on_stdout = function(_, data)
         local output = table.concat(data, "\n")
         if output == "" then
            return
         end

         local ok, result = pcall(vim.json.decode, output)
         if not ok or not result.files or not result.files[1] then
            return
         end

         local diagnostics = {}
         for _, offense in ipairs(result.files[1].offenses) do
            table.insert(diagnostics, {
               lnum = (offense.location.start_line or 1) - 1,
               col = (offense.location.start_column or 1) - 1,
               end_lnum = (offense.location.last_line or offense.location.start_line or 1) - 1,
               end_col = offense.location.last_column or offense.location.start_column or 1,
               severity = severity_map[offense.severity] or vim.diagnostic.severity.WARN,
               message = offense.message,
               source = "rubocop",
               code = offense.cop_name,
            })
         end

         vim.schedule(function()
            if vim.api.nvim_buf_is_valid(bufnr) then
               vim.diagnostic.set(rubocop_slim_ns, bufnr, diagnostics)
            end
         end)
      end,
   })
end

vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
   pattern = "*.slim",
   callback = function(args)
      rubocop_slim_lint(args.buf)
   end,
})

vim.api.nvim_create_autocmd("FileType", {
   pattern = "slim",
   callback = function(args)
      vim.keymap.set("n", ",f", function()
         local filepath = vim.api.nvim_buf_get_name(args.buf)
         vim.fn.jobstart({ "rubocop", "-a", "--no-color", filepath }, {
            on_exit = function()
               vim.schedule(function()
                  vim.cmd("edit!")
                  rubocop_slim_lint(args.buf)
               end)
            end,
         })
      end, { buffer = args.buf, desc = "Rubocop autocorrect" })
   end,
})

-- SASS responsive block splitter
local function sass_responsive_split(line1, line2)
   local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)

   local px_lines = {}
   local non_px_lines = {}
   local base_indent = nil

   for _, line in ipairs(lines) do
      if line:match("%d+px") then
         table.insert(px_lines, line)
         local indent = line:match("^(%s*)")
         if base_indent == nil or #indent < #base_indent then
            base_indent = indent
         end
      else
         table.insert(non_px_lines, line)
      end
   end

   if #px_lines == 0 then
      return
   end

   local content_indent = base_indent .. "  "
   local result = {}

   for _, line in ipairs(non_px_lines) do
      table.insert(result, line)
   end

   if #non_px_lines > 0 then
      table.insert(result, "")
   end

   table.insert(result, base_indent .. "+lte_ipad")
   for _, line in ipairs(px_lines) do
      local trimmed = line:match("^%s*(.*)")
      local converted = trimmed:gsub("(%d+px)", "rem4(%1)")
      table.insert(result, content_indent .. converted)
   end

   table.insert(result, "")

   table.insert(result, base_indent .. "+gte_laptop")
   for _, line in ipairs(px_lines) do
      local trimmed = line:match("^%s*(.*)")
      table.insert(result, content_indent .. trimmed)
   end

   vim.api.nvim_buf_set_lines(0, line1 - 1, line2, false, result)
end

vim.api.nvim_create_autocmd("FileType", {
   pattern = "sass",
   callback = function(args)
      local function set_sass_mappings()
         vim.keymap.set("n", ",r", function()
            local line = vim.fn.line(".")
            sass_responsive_split(line, line)
         end, { buffer = args.buf, desc = "SASS responsive split" })

         vim.keymap.set("v", "R", function()
            local line1 = vim.fn.line("v")
            local line2 = vim.fn.line(".")
            if line1 > line2 then
               line1, line2 = line2, line1
            end
            vim.api.nvim_feedkeys(
               vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false
            )
            sass_responsive_split(line1, line2)
         end, { buffer = args.buf, desc = "SASS responsive split (visual)" })
      end

      set_sass_mappings()

      vim.api.nvim_create_autocmd("LspAttach", {
         buffer = args.buf,
         once = true,
         callback = function()
            vim.schedule(set_sass_mappings)
         end,
      })
   end,
})

--
-- -- only highlight when searching
-- vim.api.nvim_create_autocmd("CmdlineEnter", {
--    callback = function()
--       local cmd = vim.v.event.cmdtype
--       if cmd == "/" or cmd == "?" then
--          vim.opt.hlsearch = true
--       end
--    end,
-- })
-- vim.api.nvim_create_autocmd("CmdlineLeave", {
--    callback = function()
--       local cmd = vim.v.event.cmdtype
--       if cmd == "/" or cmd == "?" then
--          vim.opt.hlsearch = false
--       end
--    end,
-- })
--
-- -- Highlight when yanking
-- vim.api.nvim_create_autocmd("TextYankPost", {
--    callback = function()
--       vim.highlight.on_yank({ timeout = 200 })
--    end,
-- })
--
-- -- Disable auto comment
-- vim.api.nvim_create_autocmd("BufEnter", {
--    callback = function()
--       vim.opt.formatoptions = { c = false, r = false, o = false }
--    end,
-- })
--
-- -- turn on spell check for markdown and text file
-- vim.api.nvim_create_autocmd("BufEnter", {
--    pattern = { "*.md" },
--    callback = function()
--       vim.opt_local.spell = true
--    end,
-- })
--
-- -- keymap for .cpp file
-- vim.api.nvim_create_autocmd("BufEnter", {
--    pattern = { "*.cpp", "*.cc" },
--    callback = function()
--       vim.keymap.set(
--          "n",
--          "<Leader>e",
--          ":terminal ./a.out<CR>",
--          { silent = true }
--       )
--       -- vim.keymap.set("n", "<Leader>e", ":!./sfml-app<CR>",
--       --    { silent = true })
--    end,
-- })
--
-- -- tab format for .lua file
-- vim.api.nvim_create_autocmd("BufEnter", {
--    pattern = { "*.lua" },
--    callback = function()
--       vim.opt.shiftwidth = 3
--       vim.opt.tabstop = 3
--       vim.opt.softtabstop = 3
--       -- vim.opt_local.colorcolumn = {70, 80}
--    end,
-- })
--
-- -- keymap for .go file
-- vim.api.nvim_create_autocmd("BufEnter", {
--    pattern = { "*.go" },
--    callback = function()
--       vim.keymap.set(
--          "n",
--          "<Leader>e",
--          ":terminal go run %<CR>",
--          { silent = true }
--       )
--    end,
-- })
--
-- -- keymap for .py file
-- vim.api.nvim_create_autocmd("BufEnter", {
--    pattern = { "*.py" },
--    callback = function()
--       vim.keymap.set(
--          "n",
--          "<Leader>e",
--          ":terminal python3 %<CR>",
--          { silent = true }
--       )
--    end,
-- })
