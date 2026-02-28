return {
  {
    "ThePrimeagen/99",
    config = function()
      local _99 = require("99")
      local cwd = vim.uv.cwd()
      local basename = vim.fs.basename(cwd)

      vim.env.CLAUDECODE = nil

      -- Custom provider that wraps claude CLI with `with-proxy`
      local ProxiedClaudeProvider =
        setmetatable({}, { __index = _99.Providers.ClaudeCodeProvider })

      function ProxiedClaudeProvider._build_command(_, query, context)
        return {
          "with-proxy",
          "claude",
          "--dangerously-skip-permissions",
          "--model",
          context.model,
          "--print",
          query,
        }
      end

      _99.setup({
        provider = ProxiedClaudeProvider,
        model = "claude-opus-4-6",
        logger = {
          level = _99.DEBUG,
          path = "/tmp/" .. basename .. ".99.debug",
          print_on_error = true,
        },
        tmp_dir = "/tmp/99",
      })

      vim.keymap.set("n", "<leader>9s", function()
        _99.search()
      end, { noremap = true, silent = true, desc = "99: Search" })

      vim.keymap.set("v", "<leader>9v", function()
        _99.visual()
      end, { noremap = true, silent = true, desc = "99: Visual replace" })

      vim.keymap.set("n", "<leader>9x", function()
        _99.stop_all_requests()
      end, { noremap = true, silent = true, desc = "99: Stop all requests" })
    end,
  },
}
