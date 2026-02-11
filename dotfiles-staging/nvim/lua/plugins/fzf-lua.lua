return {
  "ibhagwan/fzf-lua",
  -- optional for icon support
  dependencies = { "nvim-tree/nvim-web-devicons" },
  -- or if using mini.icons/mini.nvim
  -- dependencies = { "echasnovski/mini.icons" },
  winopts = {
    split = "belowright 15new", -- Creates a split at the bottom with height of 15 lines
    border = "single",          -- Add a border if desired
    preview = {
      hidden = "hidden",        -- Start with preview hidden (toggle with ctrl-p)
      border = "border",
      title = false,            -- Remove title from preview
      layout = "horizontal",
      horizontal = "right:50%"  -- Preview on the right taking 50% of width
    }
  },
  opts = {
    file_ignore_patterns = {
      "node_modules/",
      "dist/",
      ".next/",
      ".git/",
      "%.git/",
      ".gitlab/",
      "build/",
      "target/",
      ".*bin/",
      ".*obj/",
      ".*exe/",
      "%.cache",
      "%.DS_Store",
      "%.env",
      "package-lock.json",
      "pnpm-lock.yaml",
      "yarn.lock",
    },
  },
  keys = {
    { "<leader>ff",  function() require("fzf-lua").files() end },
    { "<leader>fif", function()
      require("fzf-lua").files({ cwd = vim.fn.expand('%:p:h') })
    end },
    { "<leader>flg", function() require("fzf-lua").livegrep() end },
    { "<leader>fig", function()
      local fzf = require("fzf-lua")
      fzf.grep({ cwd = vim.fn.expand('%:p:h') })
    end },
    { "<leader>flt", function()
      vim.ui.input({
        prompt = "Glob?",
      }, function(glob)
        vim.ui.input({
          prompt = "Grep for what?",
        }, function(input)
          require("fzf-lua").grep {
            rg_glob = true,
            search = input .. " -- " .. glob
          }
        end)
      end)
    end },
    { "<leader>fg", function() require("fzf-lua").grep() end },
    { "<leader>fb", function() require("fzf-lua").buffers() end },
    { "<leader>fl", function() require("fzf-lua").lines() end, desc = "Search all open buffers" },
    { "<leader>f/", function() require("fzf-lua").blines() end, desc = "Search current buffer" },
    { "<leader>fk", function() require("fzf-lua").keymaps() end, desc = "Search keymaps" },
  },
}
