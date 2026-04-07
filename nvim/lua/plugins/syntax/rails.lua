return {
  { "morr/vim-ruby" },
  { "keithbsmiley/rspec.vim" },
  {
    "tpope/vim-rails",
    init = function()
      -- require("which-key").register({
      --   { "<leader>r", group = "Rails" },
      -- })
      -- vim.keymap.set("n", "<leader>r", nil, { desc = "rspec" })
      vim.keymap.set("n", "gs", "<cmd>AV<cr>", { desc = "RSpec split view" })
      vim.keymap.set("n", "gS", "<cmd>A<cr>", { desc = "RSpec current buffer" })

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "ruby",
        callback = function(args)
          vim.keymap.set("n", "gf", function()
            local col = vim.fn.col(".")
            local line = vim.fn.getline(".")

            -- Find the Ruby constant expression (A::B::C) surrounding the cursor
            -- Match all qualified constants on the line and pick the one under cursor
            local word
            -- First try qualified constants (A::B::C), then single constants (UserMailer)
            for match_start, match, match_end in line:gmatch("()(%u[%w_]*::%u[%w_:]+)()") do
              if col >= match_start and col < match_end then
                word = match
                break
              end
            end
            if not word then
              for match_start, match, match_end in line:gmatch("()(%u%w+%u%w*)()") do
                if col >= match_start and col < match_end then
                  word = match
                  break
                end
              end
            end

            if word then
              local path = word:gsub("::", "/")
              path = path:gsub("(%u+)(%u%l)", "%1_%2")
              path = path:gsub("([%l%d])(%u)", "%1_%2")
              path = path:lower() .. ".rb"

              local candidates = { "app/" .. path, "lib/" .. path, path }
              for _, candidate in ipairs(candidates) do
                if vim.fn.filereadable(candidate) == 1 then
                  vim.cmd("edit " .. vim.fn.fnameescape(candidate))
                  return
                end
              end

              -- Try find in app/ subdirectories
              local glob = vim.fn.glob("app/**/" .. path, false, true)
              if #glob > 0 then
                vim.cmd("edit " .. vim.fn.fnameescape(glob[1]))
                return
              end

              vim.notify("File not found: " .. path, vim.log.levels.WARN)
              return
            end

            -- Fallback to vim-ruby/vim-rails gf
            local ok, cfile = pcall(vim.fn.RubyCursorFile)
            if ok and cfile and cfile ~= "" then
              local find_ok, find_err = pcall(vim.cmd, "find " .. cfile)
              if not find_ok then
                vim.notify(find_err, vim.log.levels.ERROR)
              end
            else
              local gf_ok, gf_err = pcall(vim.cmd, "normal! gf")
              if not gf_ok then
                vim.notify(gf_err, vim.log.levels.ERROR)
              end
            end
          end, { buffer = args.buf, desc = "Ruby-aware gf" })
        end,
      })

      -- example projections https://gist.github.com/henrik/5676109
      vim.g.rails_projections = {
        ["app/*.rb"] = {
          alternate = "spec/{}_spec.rb",
        },
        ["app/admin/*.rb"] = {
          alternate = "spec/controllers/admin/{}_controller_spec.rb",
        },
        ["spec/controllers/admin/*_controller_spec.rb"] = {
          alternate = "app/admin/{}.rb",
        },
        ["config/locales/*ru.yml"] = {
          alternate = "config/locales/{}en.yml",
        },
        ["config/locales/*en.yml"] = {
          alternate = "config/locales/{}ru.yml",
        },
        ["app/services/*.rb"] = {
          command = "service",
          test = "spec/services/{}_spec.rb",
          alternate = "spec/services/{}_spec.rb",
        },
        ["app/queries/*.rb"] = {
          command = "query",
          test = "spec/queries/{}_spec.rb",
          alternate = "spec/queries/{}_spec.rb",
        },
        ["app/operations/*.rb"] = {
          command = "operation",
          test = "spec/operations/{}_spec.rb",
          alternate = "spec/operations/{}_spec.rb",
        },
        ["app/value_objects/*.rb"] = {
          command = "value_object",
          test = "spec/value_objects/{}_spec.rb",
          alternate = "spec/value_objects/{}_spec.rb",
        },
        ["app/view_objects/*.rb"] = {
          command = "view_object",
          test = "spec/view_objects/{}_spec.rb",
          alternate = "spec/view_objects/{}_spec.rb",
        },
        ["app/validators/*.rb"] = {
          command = "validator",
          test = "spec/validators/{}_spec.rb",
          alternate = "spec/validators/{}_spec.rb",
        },
        ["app/errors/*.rb"] = {
          command = "error",
          test = "spec/errors/{}_spec.rb",
          alternate = "spec/errors/{}_spec.rb",
        },
        ["lib/*.rb"] = {
          command = "lib",
          test = "spec/lib/{}_spec.rb",
          alternate = "spec/lib/{}_spec.rb",
        },
      }
    end,
  },
}
