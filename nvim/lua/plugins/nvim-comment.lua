return { 
   {
      "terrortylor/nvim-comment",
      init = function()
         require('nvim_comment').setup()
         vim.keymap.set("n", ", ", ":CommentToggle<cr>", {})
         vim.keymap.set("v", ", ", ":'<,'>CommentToggle<cr>", {})
      end
   },
}
