return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    opts = {
      terminal_cmd = "with-proxy claude",
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
      { ",ca", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
      { ",cd", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
    },
  },
}
