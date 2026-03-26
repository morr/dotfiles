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
