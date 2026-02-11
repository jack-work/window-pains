-- Terminal configuration
-- ALL config lives here; terminal/ module is generic library

return {
  "akinsho/toggleterm.nvim",
  dependencies = {},  -- toggleterm is the main plugin, terminal/ is local

  config = function()
    require('terminal').setup({

      -- Shell configuration (Windows/PowerShell)
      shell = {
        shell = "has('win32') ? 'powershell' : 'pwsh'",
        shellcmdflag = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;',
        shellredir = '2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode',
        shellpipe = '2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode',
        shellquote = '',
        shellxquote = ''
      },

      -- Base toggleterm options
      toggleterm = {
        size = 10,
        open_mapping = [[<C-3>]],
        hide_numbers = true,
        shade_filetypes = {},
        shade_terminals = true,
        shading_factor = 2,
        start_in_insert = true,
        insert_mappings = true,
        persist_size = true,
        close_on_exit = true,
        direction = 'float',
        float_opts = {
          border = "curved",
          winblend = 0,
          highlights = {
            border = "Normal",
            background = "Normal"
          }
        }
      },

      -- Polymorphic terminal list
      -- Each entry needs: name (used as prefix), keymap
      -- Single-process: has cmd field
      -- Multi-process: has buffers field
      terminals = {
        -- Node CLI (yipyap)
        {
          name = "nodecli",
          keymap = "<leader>yy",
          cmd = "yipyap",
          desc = "Toggle Node CLI (yipyap)",
          singleton = true,
          direction = "float",
          float_opts = {
            border = "curved",
            width = 80,
            height = 50,
          },
        },

        -- AI Chat
        {
          name = "aichat",
          keymap = "<leader>ai",
          cmd = "aichat -r coder",
          desc = "Toggle AI Chat",
          singleton = true,
          use_ctrl = true,
          direction = "float",
          float_opts = {
            border = "curved",
            width = 150,
            height = 50,
          },
        },

        -- Claude Agency
        {
          name = "claude",
          keymap = "<leader>clark",
          cmd = "agency claude",
          desc = "Claude Agency",
          singleton = true,
          use_ctrl = true,
          direction = "float",
          float_opts = {
            border = "curved",
            width = 150,
            height = 50,
          },
        },

        -- Clyde: Claude Agency (skip permissions)
        {
          name = "clyde",
          keymap = "<leader>cly",
          cmd = "agency claude --dangerously-skip-permissions",
          desc = "Clyde (Claude skip permissions)",
          singleton = true,
          use_ctrl = true,
          searchable = true,  -- high scrollback, easy to search
          direction = "float",
          float_opts = {
            border = "curved",
            width = 150,
            height = 50,
          },
        },

        -- Dev terminals (multi-process)
        {
          name = "dev",
          keymap = "<leader>clod",
          desc = "Start dev terminals",
          singleton = true,  -- reuse existing group
          searchable = true,  -- high scrollback for all buffers
          buffers = {
            { name = "copilot", cmd = "npx copilot-api@latest start", main = false, singleton = true },
            { name = "ccr", cmd = "ccr start", main = false, singleton = true },
            { name = "claude", cmd = "ccr code", main = true, singleton = true },
          }
        },
      },

      -- Custom keymaps (non-terminal shortcuts)
      custom_keymaps = {
        {
          mode = "n",
          keymap = "<leader>th",
          desc = "Open terminal in current directory",
          action = function()
            local dir = vim.fn.expand('%:p:h')
            vim.cmd('edit term://' .. dir .. '//' .. vim.o.shell)
          end
        },
        {
          mode = "n",
          keymap = "<leader>tm",
          desc = "Open terminal with profile loaded",
          action = function()
            require('terminal.terminals').create_named_terminal(
              "term_" .. os.date("%Y%m%d-%H%M%S"),
              "pwsh -NoLogo",
              "current"
            )
          end
        },
      },

      -- Override :terminal command
      override_terminal = true,
    })
  end,
}
