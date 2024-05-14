--[[
Generate lua script suitable to be used inside of neovim to convert content of current project files into a format suitable for GPT-4 input.
Requirements:
- It must parse  content other of current file or of all project files starting from current directory recursively.
- It must open new neovim **tab** and print output in that tab.
- Format each file and its output as it suits better for GPT-4 to understand it
example of possible formatting:
<SEPARATORS><SPACE>Start:<SPACE><FILE_PATH_RELATIVE_TO_THE_PROJECT_DIR. PATH_STARTS_WITH "./"><SPACE><SEPARATORS>
```<SYNTAX_TYPE>
<FILE_CONTENT>
```
<SEPARATORS><SPACE>End:<SPACE><FILE_PATH_RELATIVE_TO_THE_PROJECT_DIR><SPACE><SEPARATORS>
where  <SEPARATORS> - is a some kind of separtor. multiple "=" for example, <SPACE> - symbol of spacebar
Where <SYNTAX_TYPE> must be one of ruby,  javascript, vue, css, sass, scss, toml, rust. If <SYNTAX_TYPE> is of unknown type, then put in its place extension of current file. Make sure code does not breaks if file has no extension.
- It must respect `.gitignore`. For example in folder `/Users/morr/develop/zxc` it should not print content of `/Users/morr/develop/zxc/target/debug/libzxc.rlib` while `/target` is in  `gitignore`.
- Add newlines between outputs of files
- Use git command line tools to respect .gitignore rules and processes files not yet staged in git.
- It must ignore content of `.git`, `tmp`, `node_modules` folders. In script code store list of these folders in a variable.
- It must ignore content of `Berksfile.lock', 'Gemfile.lock', 'yarn.lock', 'Cargo.lock', 'ai'. 'LICENSE', '.eslintrc', '.rubocop.yml' files. In script code store list of these folders in a variable.
- Exclude from output files of image types
- Exclude from output files other binary types
- Do not use external nvim packages.
- Do not explain me what you do. Just output to me the code. 
- Register two global lua functions: first to run this script for current file, second to this script for the whole project. In other words make these functions globally available by prefixing them with `_G`.
 - `<leader>a` must run this script for current file
 - `<leader>A` must run this script for the whole project

Here is you last attempt. it mostly works, but have some issues

...


Issue 1:
- it generates full url starting with root `/`. In this case I opened nvim in folder `/Users/morr/dotfiles/nvim` so the script should generate following path in line
```
===== End: ./lua/config/ai.lua =====
```
Issue 2:
- `ignored_dirs` is not used

Fix the problems of the script
]]

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

-- Helper to determine if the file should be ignored based on the directory or extension
local function is_ignored_file_path(file_path)
  for _, dir in ipairs(ignored_dirs) do
    if file_path:match("/" .. dir .. "/") then
      return true
    end
  end
  return false
end

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
    "woff",
    "woff2",
  }
  local extension = filename:match("%.([^.]+)$")
  return extension and vim.tbl_contains(ignored_ext, extension)
end

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

local function format_file_content(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("*all")
  file:close()

  local extension = path:match("%.([^.]+)$") or ""
  local syntax_type = prepare_syntax_type(extension)
  local relative_path = vim.fn.fnamemodify(path, ":.")
  local formatted_content = "===== Start: ./"
    .. relative_path
    .. " =====\n```"
    .. syntax_type
    .. "\n"
    .. content
    .. "\n```\n===== End: ./"
    .. relative_path
    .. " =====\n"
  return vim.split(formatted_content, "\n", true)
end

local function process_files(files)
  vim.cmd("tabnew")
  local bufnr = vim.api.nvim_get_current_buf()
  local output = {}

  for _, file in ipairs(files) do
    if
      not is_ignored_file_path(file)
      and not is_ignored_file_type(file)
      and not vim.tbl_contains(ignored_files, vim.fn.fnamemodify(file, ":t"))
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

local function get_project_files()
  local output =
    -- vim.fn.systemlist("git ls-files --exclude-standard '*.js' '*.vue'")
    vim.fn.systemlist("git ls-files --exclude-standard")
  if vim.v.shell_error ~= 0 then
    print("Error listing files using git")
    return {}
  end
  return output
end

function _G.process_current_file()
  local current_file = vim.fn.expand("%:p")
  process_files({ current_file })
end

function _G.process_project_files()
  local files = get_project_files()
  process_files(files)
end

vim.api.nvim_set_keymap(
  "n",
  ",ai",
  "<cmd>lua _G.process_current_file()<CR>",
  { noremap = true, silent = true, desc = "Generate file code for AI" }
)
vim.api.nvim_set_keymap(
  "n",
  ",aI",
  "<cmd>lua _G.process_project_files()<CR>",
  { noremap = true, silent = true, desc = "Generate project code for AI" }
)
