-- psmux-navigator plugin spec
-- Seamless Ctrl-h/j/k/l navigation between neovim splits and psmux panes
return {
  dir = vim.fn.stdpath("config") .. "/lua/psmux",
  config = function()
    require("psmux").setup()
  end,
}
