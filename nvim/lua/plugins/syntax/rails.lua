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

            -- Build candidate constants under the cursor.
            -- For `A::B::C` with cursor on `B`, try `A::B` first then `A::B::C`,
            -- so we extend rightward if the shorter match doesn't resolve to a file.
            local words = {}
            for match_start, match, match_end in line:gmatch("()(%u[%w_]*::%u[%w_:]+)()") do
              if col >= match_start and col < match_end then
                local segments = {}
                local cursor_idx
                local offset = match_start
                for seg in (match .. "::"):gmatch("([^:]+)::") do
                  table.insert(segments, seg)
                  local seg_end = offset + #seg
                  if not cursor_idx and col >= offset and col < seg_end then
                    cursor_idx = #segments
                  end
                  offset = seg_end + 2
                end
                if cursor_idx then
                  for i = cursor_idx, #segments do
                    table.insert(words, table.concat(segments, "::", 1, i))
                  end
                else
                  table.insert(words, match)
                end
                break
              end
            end
            if #words == 0 then
              for match_start, match, match_end in line:gmatch("()(%u[%w_]*)()") do
                if col >= match_start and col < match_end then
                  table.insert(words, match)
                  break
                end
              end
            end

            local function resolve(word)
              local path = word:gsub("::", "/")
              path = path:gsub("(%u+)(%u%l)", "%1_%2")
              path = path:gsub("([%l%d])(%u)", "%1_%2")
              path = path:lower() .. ".rb"

              for _, candidate in ipairs({ "app/" .. path, "lib/" .. path, "config/" .. path, path }) do
                if vim.fn.filereadable(candidate) == 1 then
                  return candidate, path
                end
              end

              local glob = vim.fn.glob("app/**/" .. path, false, true)
              if #glob > 0 then
                table.sort(glob, function(a, b)
                  local da = select(2, a:gsub("/", "/"))
                  local db = select(2, b:gsub("/", "/"))
                  if da ~= db then
                    return da < db
                  end
                  return a < b
                end)
                return glob[1], path
              end

              return nil, path
            end

            if #words > 0 then
              local first_path
              for _, word in ipairs(words) do
                local found, path = resolve(word)
                if found then
                  vim.cmd("edit " .. vim.fn.fnameescape(found))
                  return
                end
                first_path = first_path or path
              end
              vim.notify("File not found: " .. first_path, vim.log.levels.WARN)
              return
            end

            -- Fallback to vim-ruby/vim-rails gf
            local ok, cfile = pcall(vim.fn.RubyCursorFile)
            if ok and cfile and cfile ~= "" then
              local find_ok, find_err = pcall(vim.cmd, "find " .. vim.fn.fnameescape(cfile))
              if not find_ok and not (find_err:match("E345") or find_err:match("E447")) then
                vim.notify(find_err, vim.log.levels.ERROR)
              end
            else
              local gf_ok, gf_err = pcall(vim.cmd, "normal! gf")
              if not gf_ok and not (gf_err:match("E345") or gf_err:match("E447") or gf_err:match("E446")) then
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
