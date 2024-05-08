vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
  pattern = "*.ess",
  callback = function()
    vim.bo.filetype = "css"
  end,
})
