
return {
   { 'slim-template/vim-slim', },
   { 'morr/vim-ruby', },
   { 'vim-scripts/grep.vim', },
   { 'jparise/vim-graphql', },
   { 'keithbsmiley/rspec.vim', },
   {
      "tpope/vim-rails",
      init = function()
         vim.keymap.set("n", "<leader>s", "<cmd>AV<cr>", { desc = "Open spec in split view" })
         vim.keymap.set("n", "<leader>S", "<cmd>A<cr>", { desc = "Open spec in current buffer" })
         -- example projections https://gist.github.com/henrik/5676109
         vim.g.rails_projections = {
            ['app/*.rb'] = {
               alternate = 'spec/{}_spec.rb',
            },
            ['app/admin/*.rb'] = {
               alternate = 'spec/controllers/admin/{}_controller_spec.rb',
            },
            ['spec/controllers/admin/*_controller_spec.rb'] = {
               alternate = 'app/admin/{}.rb',
            },
            ['config/locales/*ru.yml'] = {
               alternate = 'config/locales/{}en.yml',
            },
            ['config/locales/*en.yml'] = {
               alternate = 'config/locales/{}ru.yml',
            }
         }
      end
   },
   { "keithbsmiley/rspec.vim" }
}
