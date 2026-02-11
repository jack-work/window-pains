return {
  "sindrets/diffview.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFocusFiles" },
  config = function()
    require("diffview").setup({
      diff_binaries = false,    -- Show diffs for binaries
      enhanced_diff_hl = false, -- See ':h diffview-config-enhanced_diff_hl'
      git_cmd = { "git" },      -- The git executable followed by default args
      use_icons = true,         -- Requires nvim-web-devicons
      icons = {                 -- Only applies when use_icons is true
        folder_closed = "",
        folder_open = "",
      },
      signs = {
        fold_closed = "",
        fold_open = "",
      },
      file_panel = {
        position = "left",           -- One of 'left', 'right', 'top', 'bottom'
        width = 35,                  -- Only applies when position is 'left' or 'right'
        height = 10,                 -- Only applies when position is 'top' or 'bottom'
      },
      file_history_panel = {
        position = "bottom",
        width = 35,
        height = 16,
        log_options = {   -- See ':h diffview-config-log_options'
          single_file = {
            diff_merges = "combined",
          },
          multi_file = {
            diff_merges = "first-parent",
          },
        },
      },
      commit_log_panel = {
        win_config = {},    -- See ':h diffview-config-win_config'
      },
      default_args = {    -- Default args prepended to the arg-list for the listed commands
        DiffviewOpen = {},
        DiffviewFileHistory = {},
      },
      hooks = {},         -- See ':h diffview-config-hooks'
      keymaps = {
        disable_defaults = false, -- Disable the default keymaps
        view = {
          -- Add your custom view keymaps here
        },
        file_panel = {
          -- Add your custom file panel keymaps here
        },
        file_history_panel = {
          -- Add your custom file history panel keymaps here
        },
      },
    })
  end,
  -- keys = {
  --   '<leader>dvm', ':DiffviewOpen head..master<CR>',
  --   '<leader>dvc', ':DiffviewOpen head..master<CR>',
  --   '<leader>dvr', ':DiffviewRefresh<CR>'
  -- }
}
