-- Define ignored directories and file types
local ignored_dirs = { ".git", "tmp", "node_modules", "assets" }
local ignored_files = {
  "Berksfile.lock",
  "Gemfile.lock",
  "yarn.lock",
  "Cargo.lock",
  "LICENSE",
  ".eslintrc.yml",
  ".gitignore",
  ".rubocop.yml",
}

-- Helper to determine if the file should be ignored based on the extension
local function is_ignored_file_type(filename)
  local ignored_ext = {
    "png",
    "jpg",
    "jpeg",
    "gif",
    "bmp",
    "svg",
    "ico",
    "webp",
    "tiff",
    "psd",
    "ttf",
    "svg",
    "woff",
    "woff2",
  }
  local extension = filename:match("%.([^.]+)$")
  if not extension then
    return false
  end
  return vim.tbl_contains(ignored_ext, extension)
end

-- Prepare the syntax type based on file extension or use the extension directly if not a known type
local function prepare_syntax_type(extension)
  local known_types = {
    rb = "ruby",
    js = "javascript",
    vue = "vue",
    css = "css",
    sass = "sass",
    scss = "scss",
    toml = "toml",
    rs = "rust",
  }
  return known_types[extension] or extension
end

-- Function to read and format the content of a file
local function format_file_content(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("*all")
  file:close()

  local extension = path:match("%.([^.]+)$") or ""
  local syntax_type = prepare_syntax_type(extension)
  local formatted_content = "===== Start: ./"
    .. path
    .. " =====\n```"
    .. syntax_type
    .. "\n"
    .. content
    .. "\n```\n===== End: ./"
    .. path
    .. " =====\n"
  return vim.split(formatted_content, "\n", true)
end

-- Main function to process files
local function process_files(files)
  vim.cmd("tabnew")
  local bufnr = vim.api.nvim_get_current_buf()
  local output = {}

  for _, file in ipairs(files) do
    if
      not is_ignored_file_type(file)
      and not vim.tbl_contains(ignored_files, file)
    then
      local content = format_file_content(file)
      if content then
        for _, line in ipairs(content) do
          table.insert(output, line)
        end
        table.insert(output, "") -- Ensure spacing between files
      end
    end
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, output)
end

-- Function to retrieve all relevant files respecting .gitignore
local function get_project_files()
  local output = vim.fn.systemlist("git ls-files --exclude-standard")
  if vim.v.shell_error ~= 0 then
    print("Error listing files using git")
    return {}
  end
  return output
end

-- -- Function to retrieve all relevant files respecting .gitignore
-- local function get_project_files()
--   -- Construct the git ls-files command excluding ignored directories
--   local excluded_dirs = {}
--   for _, dir in ipairs(ignored_dirs) do
--     table.insert(excluded_dirs, "--exclude=" .. dir)
--   end
--   local command = "git ls-files --exclude-standard "
--     .. table.concat(excluded_dirs, " ")
--   vim.notify(command)
--
--   -- Execute the command and retrieve output
--   local output = vim.fn.systemlist(command)
--   if vim.v.shell_error ~= 0 then
--     print("Error listing files using git")
--     return {}
--   end
--   return output
-- end

-- Global function to process current file
function _G.process_current_file()
  local current_file = vim.fn.expand("%:p")
  process_files({ current_file })
end

-- Global function to process all files in project
function _G.process_project_files()
  local files = get_project_files()
  process_files(files)
end

-- Set keybindings
vim.api.nvim_set_keymap(
  "n",
  "<leader>a",
  "<cmd>lua _G.process_current_file()<CR>",
  { noremap = true, silent = true }
)
vim.api.nvim_set_keymap(
  "n",
  "<leader>A",
  "<cmd>lua _G.process_project_files()<CR>",
  { noremap = true, silent = true }
)
