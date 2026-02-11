return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    preset = "helix",
    delay = 300,
    spec = {
      { "<leader>f", group = "find" },
      { "<leader>g", group = "git" },
      { "<leader>u", group = "toggle" },
      { "<leader>q", group = "session" },
      { "<leader>y", group = "yank" },
      { "<leader>c", group = "code/dir" },
      { "<leader>d", group = "diagnostics" },
      { "<leader>R", group = "REST" },
      { "<leader>j", group = "json/journal" },
    },
  },
  keys = {
    { "<leader>?", function() require("which-key").show({ global = false }) end, desc = "Buffer-local keymaps" },
  },
}
