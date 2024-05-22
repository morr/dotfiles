return {
  {
    "mrcjkb/rustaceanvim",
    version = "^4",
    ft = { "rust" },
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      -- neotest intergration
      require("neotest").setup({
        adapters = {
          require("rustaceanvim.neotest"),
        },
      })

      vim.g.rustaceanvim = {
        -- Plugin configuration
        -- tools = {
        -- },
        -- LSP configuration
        server = {
          ---@diagnostic disable-next-line: unused-local
          on_attach = function(client, bufnr)
            config_lsp_mappings(bufnr)

            local opts = { noremap = true, silent = true, buffer = bufnr }

            opts.desc = "See available code actions"
            vim.keymap.set({ "n", "v" }, "<leader>la", "<cmd>RustLsp codeAction<cr>", opts)
            -- vim.keymap.set(
            --   { "n", "v" },
            --   ",a",
            --   "<cmd>RustLsp codeAction<cr>",
            --   opts
            -- )
            -- vim.keymap.set(
            --   { "n", "v" },
            --   "<M-R>",
            --   "<cmd>RustLsp codeAction<cr>",
            --   opts
            -- )
            vim.keymap.set({ "n", "v" }, "<M-A>", "<cmd>RustLsp codeAction<cr>", opts)

            vim.keymap.set("n", "J", "<cmd>RustLsp joinLines<cr>", opts)

            opts.desc = "cargo run"
            vim.keymap.set(
              { "n", "i" },
              ",cR",
              "<cmd>TermExec cmd='cargo run'<cr>",
              -- "<cmd>TermExec cmd='MTL_HUD_ENABLED=1 cargo run'<cr>",
              opts
            )
            opts.desc = "cargo run and exit"
            vim.keymap.set(
              { "n", "i" },
              ",cr",
              "<cmd>TermExec cmd='cargo run; exit'<cr>",
              -- "<cmd>TermExec cmd='MTL_HUD_ENABLED=1 cargo run; exit'<cr>",
              opts
            )

            opts.desc = "cargo build"
            vim.keymap.set({ "n", "i" }, ",cb", "<cmd>TermExec cmd='cargo build'<cr>", opts)

            opts.desc = "cargo test"
            vim.keymap.set({ "n", "i" }, ",cT", "<cmd>TermExec cmd='cargo test'<cr>", opts)

            opts.desc = "Neotest: run nearest test"
            vim.keymap.set({ "n", "i" }, "<m-T>", function()
              require("neotest").run.run()
            end, opts)
          end,
          -- default_settings = {
          --   -- rust-analyzer language server configuration
          --   ['rust-analyzer'] = {
          --   },
          -- },
        },
        -- DAP configuration
        -- dap = {
        -- },
      }

      -- Set up DAP
      local dap = require("dap")
      local dapui = require("dapui")
      local home_dir = os.getenv("HOME")

      dap.adapters.lldb = {
        type = "executable",
        command = home_dir .. "/.local/share/nvim/mason/bin/codelldb",
        name = "lldb",
      }

      dap.configurations.rust = {
        {
          name = "Launch",
          type = "lldb",
          request = "launch",
          program = function()
            -- Automatically find the Rust binary
            local cargo_build_cmd = "cargo build --message-format=json"
            local cargo_output = vim.fn.systemlist(cargo_build_cmd)
            local executable = nil

            for _, line in ipairs(cargo_output) do
              local decoded = vim.fn.json_decode(line)
              if decoded and decoded.executable then
                executable = decoded.executable
                break
              end
            end

            if not executable then
              vim.notify("Executable not found in cargo build output", vim.log.levels.ERROR)
              return nil
            end

            return executable
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
          args = {},
        },
      }
      dapui.setup()

      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end

      require("nvim-dap-virtual-text").setup()

      -- DAP key mappings similar to Google Chrome for macOS
      vim.keymap.set("n", "<leader>d<space>", function()
        require("dap").continue()
      end, { desc = "Continue" })
      vim.keymap.set("n", "<leader>d<right>", function()
        require("dap").step_over()
      end, { desc = "Step Over" })
      vim.keymap.set("n", "<leader>d<down>", function()
        require("dap").step_into()
      end, { desc = "Step Into" })
      vim.keymap.set("n", "<leader>d<up>", function()
        require("dap").step_out()
      end, { desc = "Step Out" })
      vim.keymap.set("n", "<leader>db", function()
        require("dap").toggle_breakpoint()
      end, { desc = "Toggle Breakpoint" })
      vim.keymap.set("n", "<leader>dB", function()
        require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
      end, { desc = "Set Conditional Breakpoint" })
      vim.keymap.set("n", "<leader>dp", function()
        require("dap").set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
      end, { desc = "Set Log Point" })
      vim.keymap.set("n", "<leader>dr", function()
        require("dap").repl.open()
      end, { desc = "Open REPL" })
      vim.keymap.set("n", "<leader>dl", function()
        require("dap").run_last()
      end, { desc = "Run Last" })
      vim.keymap.set("n", "<leader>du", function()
        require("dapui").toggle()
      end, { desc = "Toggle DAP UI" })
    end,
  },
  {
    "mfussenegger/nvim-dap",
  },
  {
    "rcarriga/nvim-dap-ui",
    requires = { "mfussenegger/nvim-dap" },
  },
  {
    "theHamsta/nvim-dap-virtual-text",
  },
}
