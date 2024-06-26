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

      dap.adapters.codelldb = {
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
          type = "codelldb",
          request = "launch",
          program = function()
            local cargo_build_cmd =
              "cargo build --message-format=json | grep -v crates.io-index  | grep executable | grep -v '\"executable\":null'"
            local cargo_output = vim.fn.systemlist(cargo_build_cmd)

            -- Add debug print for cargo output
            -- vim.notify("Cargo build output: " .. vim.inspect(cargo_output), vim.log.levels.INFO)

            local executable = nil

            for _, line in ipairs(cargo_output) do
              local success, decoded = pcall(vim.fn.json_decode, line)
              if success and decoded and decoded.executable then
                executable = decoded.executable
                break
              end
            end

            if not executable then
              vim.notify("Executable not found in cargo build output", vim.log.levels.ERROR)
              return nil
            end

            -- vim.notify("Executable found: " .. tostring(executable), vim.log.levels.INFO)
            return executable
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
          args = {},
          env = function()
            local rustc_sysroot = vim.fn.system("rustc --print sysroot"):gsub("%s+", "") -- Trim any whitespace
            local variables = {
              -- Adding Rust library path for dynamic linker
              ["DYLD_LIBRARY_PATH"] = rustc_sysroot .. "/lib",
              -- ["DYLD_LIBRARY_PATH"] = home_dir .. "/.rustup/toolchains/nightly-aarch64-apple-darwin/lib",
              -- ["RUST_LOG"] = "debug", -- Example environment variable for Bevy
            }
            return variables
          end,
          runInTerminal = false,
          -- Set the working directory explicitly
          -- cwd = function()
          --   return vim.fn.getcwd()
          -- end,
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
