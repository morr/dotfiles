return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      local home_dir = os.getenv("HOME")

      dap.set_log_level("DEBUG")

      dap.adapters.lldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = home_dir .. "/.local/share/nvim/mason/bin/codelldb",
          args = { "--port", "${port}" },
        },
      }

      dap.configurations.rust = {
        {
          name = "Launch",
          type = "lldb",
          request = "launch",
          program = function()
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
          env = function()
            local variables = {
              -- Example environment variables for Bevy
              -- ["RUST_LOG"] = "debug",
              -- Add any additional environment variables your Bevy project might need
            }
            return variables
          end,
          runInTerminal = false,
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
}
