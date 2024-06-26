return {
  --   {
  --     "posva/vim-vue",
  --     init = function()
  --       vim.cmd([[
  --          au BufNewFile,BufRead *.vue setf vue
  --         " https://github.com/posva/vim-vue#how-to-use-commenting-functionality-with-multiple-languages-in-vue-files
  --         au FileType vue syntax sync fromstart
  --
  --         " Vim slows down when using this plugin How can I fix that?
  --         let g:vue_pre_processors = ['pug', 'sass']
  --      ]])
  --       -- -- Set filetype for .vue files
  --       -- vim.filetype.add({
  --       --   pattern = {
  --       --     ["*.vue"] = "vue",
  --       --   },
  --       -- })
  --       --
  --       -- -- Ensure syntax synchronization starts from the beginning for Vue files
  --       -- vim.api.nvim_create_autocmd("FileType", {
  --       --   pattern = "vue",
  --       --   callback = function()
  --       --     vim.cmd("syntax sync fromstart")
  --       --   end,
  --       -- })
  --       --
  --       -- -- Set global variables for Vue pre-processors
  --       -- vim.g.vue_pre_processors = { "pug", "sass" }
  --     end,
  --   },
}
