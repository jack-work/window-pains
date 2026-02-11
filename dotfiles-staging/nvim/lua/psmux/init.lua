-- psmux-navigator: seamless Ctrl-h/j/k/l navigation between nvim splits and psmux panes
-- When at the edge of a neovim split, delegates to psmux select-pane.
-- Only activates when PSMUX_SESSION env var is set (inside psmux).

local M = {}

local function is_psmux()
  return vim.env.PSMUX_SESSION ~= nil
end

local function at_edge(direction)
  local win = vim.api.nvim_get_current_win()
  vim.cmd('wincmd ' .. direction)
  local new_win = vim.api.nvim_get_current_win()
  if win ~= new_win then
    -- Moved within vim, go back and return false (not at edge)
    vim.api.nvim_set_current_win(win)
    return false
  end
  return true
end

local directions = {
  h = { wincmd = 'h', psmux = '-L' },
  j = { wincmd = 'j', psmux = '-D' },
  k = { wincmd = 'k', psmux = '-U' },
  l = { wincmd = 'l', psmux = '-R' },
}

local function navigate(dir)
  local d = directions[dir]
  if not d then return end

  if not is_psmux() then
    vim.cmd('wincmd ' .. d.wincmd)
    return
  end

  if at_edge(d.wincmd) then
    vim.fn.system('psmux select-pane ' .. d.psmux)
  else
    vim.cmd('wincmd ' .. d.wincmd)
  end
end

function M.setup()
  for dir, _ in pairs(directions) do
    vim.keymap.set({ 'n', 't' }, '<C-' .. dir .. '>', function()
      navigate(dir)
    end, { desc = 'Navigate to ' .. dir .. ' split/psmux pane' })
  end
end

return M
