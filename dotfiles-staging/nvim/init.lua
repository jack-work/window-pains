---@diagnostic disable: undefined-field, undefined-global: vim
vim.loader.enable()

-- Bootstrap lazy.nvim
vim.g.mapleader = " ";
vim.g.maplocalleader = " ";

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Plugin setup
require("lazy").setup("plugins")

require('mason').setup()
require("mason-lspconfig").setup({
  ensure_installed = { "powershell_es" }
})

require('lspconfig').powershell_es.setup {
  bundle_path = vim.fn.stdpath "data" .. "/mason/packages/powershell-editor-services",
}

require('lspconfig').lua_ls.setup {}

require('cmp').setup({
  snippet = {
    expand = function(args)
      require('luasnip').lsp_expand(args.body)
    end,
  },
  mapping = {
    ['<C-p>'] = require('cmp').mapping.select_prev_item(),
    ['<C-n>'] = require('cmp').mapping.select_next_item(),
    ['<C-d>'] = require('cmp').mapping.scroll_docs(-4),
    ['<C-f>'] = require('cmp').mapping.scroll_docs(4),
    ['<C-Space>'] = require('cmp').mapping.complete(),
    ['<CR>'] = require('cmp').mapping.confirm({
      behavior = require('cmp').ConfirmBehavior.Replace,
      select = true
    }),
  },
  sources = {
    { name = 'nvim_lsp' },
    { name = 'luasnip' },
    { name = 'buffer' },
    { name = 'path' }
  }
})
-- Function to open a file in a bottom split using nvr
local function open_in_bottom_split(file)
  -- Ensure we're in the main Neovim instance
  if vim.env.NVIM_LISTEN_ADDRESS then
    -- We're in a nested Neovim, use nvr
    vim.fn.system(string.format("nvr --remote-send '<C-\\><C-N>:split %s<CR>:wincmd J<CR>'", file))
  else
    -- We're in the main instance, just open the file
    vim.cmd('split ' .. file)
    vim.cmd('wincmd J')
  end
end

-- Create a command to open a file in a bottom split
vim.api.nvim_create_user_command('NvrBottomSplit', function(opts)
  open_in_bottom_split(opts.args)
end, { nargs = 1, complete = 'file' })

vim.keymap.set('n', '<leader>vsp', function()
  vim.cmd('vsplit ' .. vim.fs.joinpath(vim.fn.expand('%:p:h'), vim.fn.expand('<cfile>')))
end, { noremap = true })
vim.api.nvim_set_keymap('n', '<Leader>bs', ':NvrBottomSplit ', { noremap = true })

vim.api.nvim_set_keymap('n', '<leader>rr', ':so $myvimrc<CR>', { noremap = true, silent = true })
-- C-h/j/k/l navigation handled by psmux plugin (lua/plugins/psmux.lua)
-- Falls through to psmux pane navigation when at edge of nvim splits
vim.keymap.set('n', '<C-A-h>', '<C-w>H', { desc = 'Move to left split' })
vim.keymap.set('n', '<C-A-l>', '<C-w>L', { desc = 'Move to right split' })
vim.keymap.set('n', '<C-A-j>', '<C-w>J', { desc = 'Move to down split' })
vim.keymap.set('n', '<C-A-k>', '<C-w>K', { desc = 'Move to up split' })
vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, {})
vim.keymap.set({ 'n', 'v' }, 'gr', '<cmd>FzfLua lsp_references<CR>', { noremap = true })
vim.keymap.set({ 'n', 'v' }, '<leader>fo', vim.lsp.buf.format)
-- fugitive shortcuts

vim.api.nvim_create_user_command('Bless', function()
  local main = vim.fn.system('git rev-parse --abbrev-ref origin/HEAD'):gsub("origin/", ""):gsub("\n", "")
  vim.cmd('Git stash --include-untracked')
  vim.cmd('Git checkout ' .. main)
  vim.cmd('Git pull')
  vim.cmd('Git checkout -')
  vim.cmd('Git rebase ' .. main)
end, {})

-- Optional keymap
vim.keymap.set('n', '<leader>bl', ':Bless<CR>', { silent = true })

-- Go to definition
vim.keymap.set('n', 'gd', vim.lsp.buf.definition)
-- Go to declaration
vim.keymap.set('n', 'gD', vim.lsp.buf.declaration)
-- Show hover information
vim.keymap.set('n', 'K', vim.lsp.buf.hover)
-- Go to implementation
vim.keymap.set('n', 'gi', vim.lsp.buf.implementation)
vim.keymap.set('n', 'gl', vim.diagnostic.open_float)
-- Map both normal and visual mode
vim.keymap.set({ 'n', 'v' }, '<leader>.', vim.lsp.buf.code_action)

vim.wo.number = true
vim.wo.relativenumber = true
vim.wo.wrap = false
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
})
vim.o.shell = "pwsh.exe"
vim.o.shellcmdflag = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;'
vim.o.shellredir = '2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode'
vim.o.shellpipe = '2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode'
vim.o.shellquote = ''
vim.o.shellxquote = ''

vim.opt.tabstop = 2      -- Width of tab character
vim.opt.softtabstop = 2  -- Fine tunes amount of whitespace
vim.opt.shiftwidth = 2   -- Width of indentation

vim.opt.expandtab = true -- Convert tabs to spaces
vim.opt.smartcase = true
vim.opt.ignorecase = true
vim.opt.cursorline = true

vim.g.netrw_bufsettings = 'noma nomod nu nowrap ro nobl'
vim.keymap.set('n', '<M-k>', ':resize +2<CR>')
vim.keymap.set('n', '<M-j>', ':resize -2<CR>')
vim.keymap.set('n', '<M-h>', ':vertical resize -2<CR>')
vim.keymap.set('n', '<M-l>', ':vertical resize +2<CR>')

vim.keymap.set('n', '<leader>ev', ':e $MYVIMRC<CR>')
vim.keymap.set('n', '<leader>cd', ':cd %:p:h<CR>', { desc = 'Change to current file directory' })
vim.keymap.set('n', '<leader>c-', ':cd -<CR>', { desc = 'Change to previous directory' })
vim.keymap.set('t', '<esc><esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- copy path to current file
-- :let @+ = expand('%:p')
vim.keymap.set({ 'n', 'v' }, '<leader>yp', ':let @+ = expand(\'%:p\')<CR>',
  { desc = 'yank current file path to clipboard' })
vim.keymap.set('n', '<leader>op', ':%y+<CR>',
  { desc = 'copy entire buffer to system clipboard' })
vim.keymap.set('n', '<leader><leader>', ':noh<CR>', { silent = true, desc = 'Clear search highlighting' })
vim.keymap.set('n', '<leader>dq', ':lua vim.diagnostic.setqflist()<CR>',
  { desc = 'open diagnostics in a buffer so they can be searched' })

vim.api.nvim_create_user_command('Timestamp', function()
  local timestamp = os.date('[%Y-%m-%d %H:%M:%S]')
  vim.api.nvim_put({ timestamp }, '', false, true)
end, {})

vim.keymap.set('n', '<leader>gu', function()
  -- Get current file's relative path
  local relative_path = vim.fn.fnamemodify(vim.fn.expand('%'), ':.')
  -- Convert backslashes to forward slashes
  relative_path = string.gsub(relative_path, "\\", "/")
  -- Get cursor position
  local cursor_line = vim.fn.line('.')
  local cursor_end_line = cursor_line
  -- Build the URL with line highlighting
  local url = "https://msazure.visualstudio.com/OneAgile/_git/PowerApps-Client?path=/" .. relative_path
  url = url .. "&line=" .. cursor_line .. "&lineEnd=" .. cursor_end_line
  url = url .. "&lineStartColumn=1&lineEndColumn=46&lineStyle=plain&_a=contents"
  -- Copy to clipboard
  vim.fn.setreg('+', url)
  print("Azure DevOps URL copied to clipboard: " .. url)
end, {})

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.opt_local.number = true
    vim.opt_local.relativenumber = true
  end,
})

vim.keymap.set({ "n", "v" }, "<leader>m", "<C-w>|<C-w>_")
vim.keymap.set("i", "<C-S-m>", "<esc><C-w>|<C-w>_i")


vim.keymap.set('n', ']d', function()
  -- Try each severity level in order of importance
  local severities = {
    vim.diagnostic.severity.ERROR,
    vim.diagnostic.severity.WARN,
    vim.diagnostic.severity.INFO,
    vim.diagnostic.severity.HINT,
  }

  for _, severity in ipairs(severities) do
    local next = vim.diagnostic.get_next({ severity = severity })
    if next then
      vim.diagnostic.goto_next({ severity = severity })
      return
    end
  end

  -- If no diagnostics of any severity, just call goto_next (will show "No more diagnostics")
  vim.diagnostic.goto_next()
end, { desc = 'Go to next diagnostic (prioritized)' })

vim.keymap.set('n', '[d', function()
  local severities = {
    vim.diagnostic.severity.ERROR,
    vim.diagnostic.severity.WARN,
    vim.diagnostic.severity.INFO,
    vim.diagnostic.severity.HINT,
  }

  for _, severity in ipairs(severities) do
    local prev = vim.diagnostic.get_prev({ severity = severity })
    if prev then
      vim.diagnostic.goto_prev({ severity = severity })
      return
    end
  end

  vim.diagnostic.goto_prev()
end, { desc = 'Go to previous diagnostic (prioritized)' })

-- GENERATE A GUID AND PUT IT IN THE CLIPBOARD
vim.api.nvim_create_user_command('GenGuid', function()
  local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  local guid = template:gsub('[xy]', function(c)
    local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format('%x', v)
  end)

  vim.fn.setreg('"', guid) -- default register
  vim.fn.setreg('+', guid) -- system clipboard
  vim.fn.setreg('*', guid) -- primary selection (X11)

  print('GUID copied: ' .. guid)
end, {})
vim.keymap.set("n", "<leader>guid", ":GenGuid<CR>")

-- Initialize random seed (put this outside the command)
math.randomseed(os.time() + os.clock() * 1000)

-- Runs the nearest Get-Token.ps1 ancestor script
-- Also contains an implementation of updating file buffer that can probably be generalized.
vim.keymap.set("n", "<leader>Tt", function()
  -- Get the directory of the current buffer
  local current_file = vim.api.nvim_buf_get_name(0)
  local current_dir = vim.fn.fnamemodify(current_file, ':p:h')

  -- Search for Get-Token.ps1 in ancestor directories
  local script_file = vim.fn.findfile('Get-Token.ps1', current_dir .. ';')

  if script_file == '' then
    vim.notify("Get-Token.ps1 not found in ancestor directories", vim.log.levels.ERROR)
    return
  end

  -- Get the absolute path and directory of the script
  local script_path = vim.fn.fnamemodify(script_file, ':p')
  local script_dir = vim.fn.fnamemodify(script_file, ':p:h')

  -- Create a new buffer for output
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, 'Get-Token Output')

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  vim.api.nvim_buf_set_option(buf, 'filetype', 'powershell')
  vim.api.nvim_buf_set_option(buf, 'fileformat', 'unix')

  -- Open the buffer in a split
  vim.cmd('split')
  vim.api.nvim_win_set_buf(0, buf)

  -- Add initial message
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "Running: pwsh -File " .. script_path,
    "Working Directory: " .. script_dir,
    string.rep("-", 80),
    ""
  })

  local line_count = 4

  -- Helper function to strip carriage returns
  local function strip_cr(lines)
    return vim.tbl_map(function(line)
      return line:gsub('\r', '')
    end, lines)
  end

  -- Run the script using pwsh
  local cmd = string.format('pwsh -File "%s"', script_path)

  vim.fn.jobstart(cmd, {
    cwd = script_dir, -- Set working directory to script's directory
    on_stdout = function(_, data)
      if data then
        -- Filter out empty strings and strip CR
        local lines = vim.tbl_filter(function(line)
          return line ~= ''
        end, strip_cr(data))

        if #lines > 0 then
          vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, lines)
          line_count = line_count + #lines

          -- Auto-scroll to bottom
          local wins = vim.fn.win_findbuf(buf)
          for _, win in ipairs(wins) do
            vim.api.nvim_win_set_cursor(win, { line_count, 0 })
          end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        local lines = vim.tbl_filter(function(line)
          return line ~= ''
        end, strip_cr(data))

        if #lines > 0 then
          -- Prefix error lines with [ERROR]
          local error_lines = vim.tbl_map(function(line)
            return "[ERROR] " .. line
          end, lines)

          vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, error_lines)
          line_count = line_count + #error_lines

          -- Auto-scroll to bottom
          local wins = vim.fn.win_findbuf(buf)
          for _, win in ipairs(wins) do
            vim.api.nvim_win_set_cursor(win, { line_count, 0 })
          end
        end
      end
    end,
    on_exit = function(_, exit_code)
      local status_lines = {
        "",
        string.rep("-", 80),
      }

      if exit_code == 0 then
        table.insert(status_lines, "✓ Process completed successfully (exit code: 0)")
      else
        table.insert(status_lines, "✗ Process failed (exit code: " .. exit_code .. ")")
      end

      vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, status_lines)
      line_count = line_count + #status_lines

      -- Make buffer read-only after completion
      vim.api.nvim_buf_set_option(buf, 'modifiable', false)

      -- Auto-scroll to bottom
      local wins = vim.fn.win_findbuf(buf)
      for _, win in ipairs(wins) do
        vim.api.nvim_win_set_cursor(win, { line_count, 0 })
      end
    end,
    stdout_buffered = false,
    stderr_buffered = false,
  })
end)
