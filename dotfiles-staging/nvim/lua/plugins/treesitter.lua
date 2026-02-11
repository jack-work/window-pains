return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = { "c_sharp", "typescript", "javascript" },
      highlight = { enable = true },
    })
  end,
}
