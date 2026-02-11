return {
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('lualine').setup {
        options = {
          icons_enabled = true,
          theme = 'auto',
          component_separators = { left = '', right = '' },
          section_separators = { left = '', right = '' },
          disabled_filetypes = {
            statusline = {},
            winbar = {},
          },
          ignore_focus = {},
          always_divide_middle = true,
          always_show_tabline = true,
          globalstatus = false,
          refresh = {
            statusline = 100,
            tabline = 100,
            winbar = 100,
          }
        },
        sections = {
          lualine_a = { 'mode' },
          lualine_b = { 'branch', 'diff', 'diagnostics' },
          lualine_c = {
            {
              function()
                -- In terminal buffers, use OSC 7 reported cwd if available
                local cwd
                if vim.bo.buftype == 'terminal' then
                  cwd = vim.b.osc7_dir or vim.fn.getcwd()
                else
                  cwd = vim.fn.getcwd()
                end
                local home = vim.env.USERPROFILE or vim.env.HOME or ''
                if home ~= '' then
                  -- Normalize separators for comparison
                  local cwd_norm = cwd:gsub('\\', '/')
                  local home_norm = home:gsub('\\', '/')
                  if cwd_norm:sub(1, #home_norm) == home_norm then
                    cwd = '~' .. cwd_norm:sub(#home_norm + 1)
                  else
                    cwd = cwd_norm
                  end
                else
                  cwd = cwd:gsub('\\', '/')
                end
                return cwd
              end,
              icon = '',
              color = { fg = '#7aa2f7' },
            },
            { 'filename', path = 1 },
          },
          lualine_x = { 'filetype' },
          lualine_y = { 'progress' },
          lualine_z = { 'location' }
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { { 'filename', path = 1 } },
          lualine_x = { 'location' },
          lualine_y = {},
          lualine_z = {}
        },
        tabline = {},
        winbar = {},
        inactive_winbar = {},
        extensions = { 'oil' }
      }
    end
  },
  {
    'fgheng/winbar.nvim',
    config = function()
      require('winbar').setup({
        enabled = true,

        show_file_path = true,
        show_symbols = true,

        colors = {
          path = '', -- You can customize colors like #c946fd
          file_name = '',
          symbols = '',
        },

        icons = {
          file_icon_default = '',
          seperator = '>',
          editor_state = '●',
        },

        exclude_filetype = {
          '',
          'help',
          'startify',
          'dashboard',
          'packer',
          'neogitstatus',
          'NvimTree',
          'Trouble',
          'alpha',
          'lir',
          'Outline',
          'spectre_panel',
          'toggleterm',
          'qf',
        }
      })
    end
  }
}
