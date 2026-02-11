return {
  'mfussenegger/nvim-dap',
  dependencies = {
    'mxsdev/nvim-dap-vscode-js'
  },
  config = function()
    local dap = require("dap")
    -- Python configuration
    dap.adapters.python = {
      type = 'executable',
      command = 'python',
      args = { '-m', 'debugpy.adapter' }
    }

    dap.configurations.python = {
      {
        type = 'python',
        request = 'launch',
        name = 'Launch file',
        program = '${file}',
        pythonPath = function()
          return '/usr/bin/python'
        end
      }
    }

    -- Set keymaps to control the debugger
    vim.keymap.set('n', '<F5>', require 'dap'.continue)
    vim.keymap.set('n', '<F10>', require 'dap'.step_over)
    vim.keymap.set('n', '<F11>', require 'dap'.step_into)
    vim.keymap.set('n', '<F12>', require 'dap'.step_out)
    vim.keymap.set('n', '<leader>b', require 'dap'.toggle_breakpoint)
    vim.keymap.set('n', '<leader>B', function()
      require 'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))
    end)

  end,
  dependencies = {
    'rcarriga/nvim-dap-ui',
    'theHamsta/nvim-dap-virtual-text'
  }
}
