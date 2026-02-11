---@diagnostic disable: undefined-field, undefined-global: vim
return {
  { 'williamboman/mason.nvim' },
  { 'williamboman/mason-lspconfig.nvim' },
  {
    'neovim/nvim-lspconfig',
    config = function()
      vim.keymap.set('n', '<leader>ld', vim.diagnostic.open_float, { desc = 'open_float, open code float' })
    end,
  },
  {
    'hrsh7th/nvim-cmp',
    'hrsh7th/cmp-nvim-lsp',
    'hrsh7th/cmp-buffer',
    'hrsh7th/cmp-path',
    'L3MON4D3/LuaSnip',
    'saadparwaiz1/cmp_luasnip',
  },
  {
    'rebelot/kanagawa.nvim',
    theme = 'wave',
    lazy = false,
    priority = 1000,
    config = function()
      require('kanagawa').setup({
        transparent = true,
        terminalColors = true,
        theme = 'dragon',
        undercurl = true,
        keywordStyle = { italic = true },
      })
      vim.cmd.colorscheme('kanagawa')
    end
  },
  {
    'tpope/vim-fugitive',
    'tpope/vim-rhubarb', -- GitHub integration
    -- 'lewis6991/gitsigns.nvim', -- Git signs in gutter
    keys = {
      { "<leader>gs", ":Git<CR>",            desc = "Git status" },
      { "<leader>gd", ":Gdiff<CR>",          desc = "Git diff" },
      { "<leader>rb", ":Git rebase -i HEAD~" },
    },
  },
}
