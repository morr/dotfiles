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
      }
    end,
  },
}
