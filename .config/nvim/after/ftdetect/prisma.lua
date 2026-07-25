vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.prisma", "schema.prisma" },
  desc = "Detect and set the proper file type for Prisma schema files",
  callback = function()
    vim.cmd(":set filetype=prisma")
  end,
})
