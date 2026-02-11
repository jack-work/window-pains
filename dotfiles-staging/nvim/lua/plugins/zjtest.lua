return {
  dir = vim.fn.stdpath("config") .. "/lua/zj",
  config = function()
    require("zj").setup()
  end
}

