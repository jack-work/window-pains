local M = {}

function escape_json_string()
  -- Get visually selected text
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.fn.getline(start_pos[2], end_pos[2])

  -- Handle multi-line selections
  if #lines > 1 then
    for i = 1, #lines do
      if i == 1 then
        lines[i] = string.sub(lines[i], start_pos[3])
      elseif i == #lines then
        lines[i] = string.sub(lines[i], 1, end_pos[3])
      end
    end
  else
    lines[1] = string.sub(lines[1], start_pos[3], end_pos[3])
  end

  local text = table.concat(lines, "\n")

  -- Parse JSON to validate it
  local status, decoded = pcall(vim.fn.json_decode, text)
  if not status then
    vim.notify("Invalid JSON input", vim.log.levels.ERROR)
    return
  end

  -- Re-encode to ensure proper formatting
  local formatted_json = vim.fn.json_encode(decoded)

  -- Escape special characters
  local escaped = formatted_json:gsub('\\', '\\\\')
      :gsub('"', '\\"')
      :gsub('\n', '\\n')
      :gsub('\r', '\\r')
      :gsub('\t', '\\t')

  -- Create the final string with quotes
  local final_string = '"' .. escaped .. '"'

  -- Write to the * register (system clipboard)
  vim.fn.setreg('*', final_string)
  vim.notify("JSON escaped and copied to clipboard", vim.log.levels.INFO)
end

function unescape_json_string()
  -- Get text from default register
  local escaped_text = vim.fn.getreg('"')

  -- Remove surrounding quotes if they exist
  escaped_text = escaped_text:match('^"(.*)"$') or escaped_text

  -- Unescape special characters
  local unescaped = escaped_text:gsub('\\\\', '\\')
      :gsub('\\"', '"')
      :gsub('\\n', '\n')
      :gsub('\\r', '\r')
      :gsub('\\t', '\t')

  -- Try to parse as JSON to validate and pretty print
  local status, decoded = pcall(vim.fn.json_decode, unescaped)
  if not status then
    vim.notify("Invalid JSON input", vim.log.levels.ERROR)
    return
  end

  -- Format the JSON and insert it at cursor
  local formatted_json = vim.fn.json_encode(decoded)
  local lines = vim.split(formatted_json, '\n')
  vim.api.nvim_put(lines, 'l', true, true)
  vim.notify("JSON unescaped and inserted", vim.log.levels.INFO)
end

vim.api.nvim_create_user_command('JsonEscape', function()
  escape_json_string()
end, { range = true })

vim.api.nvim_create_user_command('JsonDecode', function()
  unescape_json_string()
end, {})

vim.keymap.set('v', '<leader>je', ':JsonEscape<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>jd', ':JsonDecode<CR>', { noremap = true, silent = true })

return M
