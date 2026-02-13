return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>f",
      function()
        require("conform").format({ async = true })
      end,
      desc = "Format buffer",
    },
  },
  opts = {
    formatters_by_ft = {
      javascript = { "prettier" },
      typescript = { "prettier" },
      javascriptreact = { "prettier" },
      typescriptreact = { "prettier" },
      json = { "prettier" },
      html = { "prettier" },
      css = { "prettier" },
      scss = { "prettier" },
      markdown = { "prettier" },
      yaml = { "prettier" },
    },
    format_on_save = function(bufnr)
      local ft = vim.bo[bufnr].filetype
      if ft == "typescript" or ft == "typescriptreact" then
        return false
      end
      return { timeout_ms = 1000, lsp_fallback = true }
    end,
  },
}
