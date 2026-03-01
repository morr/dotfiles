# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Lua-based Neovim configuration managed with **lazy.nvim**. It lives within a larger dotfiles repo at `~/dotfiles/nvim/`.

## Structure

- `init.lua` — Entry point, loads all config modules in order
- `lua/config/` — Core configuration: options, keymaps, autocommands, LSP mappings, utilities
- `lua/plugins/` — Plugin specs for lazy.nvim (one file per concern)
- `lua/plugins/lsp/` — LSP server configs (`lspconfig.lua`) and installer (`mason.lua`)
- `lua/plugins/syntax/` — Language-specific plugin specs (rails, rust, vue, yaml, etc.)

## Key Conventions

- **Plugin manager**: lazy.nvim with auto-bootstrap in `lua/config/lazy.lua`. Plugin specs are imported from `plugins`, `plugins.syntax`, and `plugins.lsp` directories.
- **Leader key**: `\` (backslash)
- **Keymap helper**: `lua/config/mappings.lua` defines a local `map()` wrapper around `vim.keymap.set` with `noremap=true, silent=true` defaults.
- **LSP keymaps**: Defined globally via `config_lsp_mappings(bufnr)` in `lua/config/lsp_mappings.lua`, attached on `LspAttach` event.
- **Formatting**: Lua files use StyLua (`stylua.toml`: 2-space indent, 120-column width).

## Architecture Notes

- **Autocmds** (`lua/config/autocmds.lua`) contain non-trivial custom logic: a Slim file rubocop linter, a SASS responsive-block splitter/merger (`,r` normal / `<C-r>` visual), and file-type overrides.
- **AI helper** (`lua/config/ai.lua`) exposes `process_current_file()` and `process_project_files()` globally for formatting code as AI-ready markdown blocks. Respects `.gitignore` via `git ls-files`.
- **Rust development** has deep integration: rustaceanvim for LSP, nvim-dap with codelldb for debugging, neotest via rustaceanvim, and cargo keymaps (`,cR` run, `,cb` build, `,cT` test).
- **Completion** uses nvim-cmp with sources: nvim_lsp, nvim_lua, buffer, path, cmdline. `<Tab>` auto-completes single matches; `<C-n>/<C-p>` navigates; `<CR>` confirms.
- **Diagnostics** toggle between virtual text and virtual_lines with `<leader>ll`.

## Development Targets

Primary languages: Ruby/Rails, Rust, JavaScript/Vue, SASS/CSS. LSP servers are auto-installed via mason.nvim.

## Git

- Do not use `git -C` to change to the repo root. Git works fine from any subdirectory — just use paths relative to the current working directory.
