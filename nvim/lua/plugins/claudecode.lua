return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    opts = {
      terminal_cmd = "with-proxy claude",
      diff_opts = {
        keep_terminal_focus = true,
      },
      env = {
        NO_PROXY = "localhost,127.0.0.1,::1",
        no_proxy = "localhost,127.0.0.1,::1",
      },
    },
    keys = {
      { ",c", nil, desc = "AI/Claude Code" },
      { ",cc", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
      { ",cf", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
      { ",cr", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
      { ",cC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
      { ",cm", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
      { ",cb", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
      { ",cs", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
      {
        ",cs",
        "<cmd>ClaudeCodeTreeAdd<cr>",
        desc = "Add file",
        ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw" },
      },
      -- cmd+shift+c continue/focus Claude (wezterm sends Alt+Shift+c)
      {
        "<M-C>",
        function()
          -- Check if a Claude terminal buffer already exists
          for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if
              vim.api.nvim_buf_is_valid(buf)
              and vim.bo[buf].buftype == "terminal"
              and vim.api.nvim_buf_get_name(buf):find("claude")
            then
              vim.cmd("ClaudeCodeFocus")
              return
            end
          end
          vim.cmd("ClaudeCode --continue")
        end,
        mode = { "n", "t" },
        desc = "Continue/Focus Claude",
      },
      { ",ca", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
      { ",cd", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
      -- cmd+] / cmd+[ window navigation (wezterm sends Alt+]/Alt+[)
      { "<M-]>", "<C-w>l", mode = "n", desc = "Go to right window" },
      { "<M-]>", "<C-\\><C-n><C-w>l", mode = "t", desc = "Go to right window" },
      { "<M-[>", "<C-w>h", mode = "n", desc = "Go to left window" },
      { "<M-[>", "<C-\\><C-n><C-w>h", mode = "t", desc = "Go to left window" },
    },
  },
}
