local M = {}
local function extract_code_block_content(lines, start_line)
  local content = {}
  local i = start_line + 1
  while i <= #lines and not lines[i]:match("^```") do
    table.insert(content, lines[i])
    i = i + 1
  end
  return table.concat(content, "\n")
end

local function create_file_with_content(file_path, content)
  local dir = vim.fn.fnamemodify(file_path, ":h")
  if dir ~= "." then
    vim.fn.mkdir(dir, "p")
  end

  local file = io.open(file_path, "w")
  if file then
    file:write(content)
    file:close()
    return true
  end
  return false
end

function M.create_file_with_code()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  local file_path = vim.fn.expand("<cfile>")
  if file_path then
    vim.notify(file_path)
    -- Look for code block in subsequent lines
    for i = cursor_line + 1, #lines do
      if lines[i]:match("^```") then
        local content = extract_code_block_content(lines, i)
        if create_file_with_content(file_path, content) then
          vim.notify("File created: " .. file_path, vim.log.levels.INFO)
          -- Delete the file so it's not saved yet
          os.remove(file_path)
          -- Create a new buffer with the content
          vim.cmd('edit ' .. vim.fn.fnameescape(file_path))
          local buf = vim.api.nvim_get_current_buf()
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, '\n'))
        else
          vim.notify("Failed to create file: " .. file_path, vim.log.levels.ERROR)
        end
        break
      end
    end
  else
    vim.notify("No valid file path found at cursor position", vim.log.levels.WARN)
  end
end

function M.copy_cursor_location()
  local filename = vim.fn.expand('%:p')
  local line = vim.fn.line('.')
  local col = vim.fn.col('.')
  local location = string.format('%s:%d:%d', filename, line, col)
  vim.fn.setreg('*', location)
  vim.fn.setreg('+', location)
end

function M.copy_file_link()
  -- Get the full path of current buffer
  local current_file = vim.fn.expand('%:p')

  -- Convert to Windows path format if on Windows
  if vim.fn.has('win32') == 1 then
    current_file = current_file:gsub('/', '\\')
  end

  -- Create PowerShell command to copy file to clipboard
  local ps_command
  if vim.fn.has('win32') == 1 then
    ps_command = string.format('powershell.exe -command "Get-Item \'%s\' | Set-Clipboard -AsFileDropList"', current_file)
  else
    -- For Linux/macOS, you might need to implement a different approach
    vim.notify("File copy to clipboard is currently only supported on Windows", vim.log.levels.WARN)
    return
  end

  -- Execute the command
  local result = vim.fn.system(ps_command)

  if vim.v.shell_error == 0 then
    vim.notify("File copied to clipboard", vim.log.levels.INFO)
  else
    vim.notify("Failed to copy file to clipboard: " .. vim.v.shell_error, vim.log.levels.ERROR)
  end
end

return M
