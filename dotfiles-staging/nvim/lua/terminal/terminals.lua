-- Terminal management functions
-- Generic library - receives all config at runtime via setup()

local M = {}

-- Local state (not global)
local Terminal = nil
local instance_counter = {}  -- { [prefix] = number }
local buffer_registry = {}   -- { [prefix] = { buffers = {id, id, ...}, config = {...} } }

-- Set Terminal class reference (called during setup)
function M.set_terminal_class(terminal_class)
  Terminal = terminal_class
end

-- Check if a buffer ID is still valid
local function buffer_valid(buf_id)
  return buf_id and vim.api.nvim_buf_is_valid(buf_id)
end

-- Get next instance number for a prefix
local function get_next_instance(prefix)
  instance_counter[prefix] = (instance_counter[prefix] or 0) + 1
  return instance_counter[prefix]
end

-- Generate buffer name: prefix for first, prefix_N for subsequent
local function make_buffer_name(prefix, instance_num)
  if instance_num == 1 then
    return prefix
  end
  return prefix .. "_" .. instance_num
end

-- Find existing buffer by prefix in registry
local function find_buffer_in_registry(prefix, sub_name)
  local key = sub_name and (prefix .. "_" .. sub_name) or prefix
  local entry = buffer_registry[key]
  if entry and buffer_valid(entry.buf_id) then
    return entry.buf_id
  end
  return nil
end

-- Register a buffer
local function register_buffer(prefix, sub_name, buf_id, config)
  local key = sub_name and (prefix .. "_" .. sub_name) or prefix
  buffer_registry[key] = {
    buf_id = buf_id,
    config = config
  }
end

-- Create a terminal buffer with environment variables
-- searchable: if true, set high scrollback for searching
local function create_term_buffer(name, cmd, searchable)
  vim.cmd('enew')

  vim.fn.termopen({ 'pwsh', '-NoExit', '-Command', cmd }, {
    env = {
      VIM_SERVERNAME = vim.v.servername or 'VIMSERVER',
      VIM_LISTEN_ADDRESS = vim.v.servername
    }
  })

  local buf_id = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(buf_id, name)

  vim.schedule(function()
    vim.bo[buf_id].syntax = ''
    vim.wo.signcolumn = 'no'
    vim.wo.spell = false
    -- searchable = true means buffer is listed (shows in buffer pickers)
    vim.bo[buf_id].buflisted = searchable or false
  end)

  return buf_id
end

-- Handle a single-process terminal invocation
-- Returns the buffer ID
function M.invoke_single(term_config, toggleterm_instance)
  local prefix = term_config.name

  if term_config.singleton then
    -- Singleton: reuse or recreate
    if toggleterm_instance then
      toggleterm_instance:toggle()
      return
    end
  else
    -- Non-singleton: always create new numbered instance
    -- (This path used when not using toggleterm)
    local instance_num = get_next_instance(prefix)
    local buf_name = make_buffer_name(prefix, instance_num)
    local buf_id = create_term_buffer(buf_name, term_config.cmd)
    return buf_id
  end
end

-- Handle a multi-process terminal invocation
-- config format: { name = "dev", buffers = { {name, cmd, main, singleton}, ... } }
function M.invoke_multi(config)
  local prefix = config.name
  local main_buf = nil
  local created_main = false
  local original_buf = vim.api.nvim_get_current_buf()  -- Save original buffer

  -- Determine if we need new instances (non-singleton with existing buffers)
  local needs_new_group = not config.singleton
  local instance_num = 1

  if needs_new_group then
    -- Check if any buffer from this group exists
    local any_exists = false
    for _, buf_cfg in ipairs(config.buffers) do
      local key = prefix .. "_" .. buf_cfg.name
      if buffer_registry[key] and buffer_valid(buffer_registry[key].buf_id) then
        any_exists = true
        break
      end
    end

    if any_exists then
      instance_num = get_next_instance(prefix)
    else
      instance_counter[prefix] = 1
      instance_num = 1
    end
  end

  -- Process each buffer in the group
  for _, buf_cfg in ipairs(config.buffers) do
    local sub_name = buf_cfg.name
    local full_prefix = prefix .. "_" .. sub_name
    local buf_name = make_buffer_name(full_prefix, instance_num)

    local existing_buf = nil
    if buf_cfg.singleton or config.singleton then
      existing_buf = find_buffer_in_registry(prefix, sub_name)
    end

    if existing_buf then
      -- Buffer exists and is singleton, reuse it
      if buf_cfg.main then
        main_buf = existing_buf
      end
    else
      -- Create new buffer (inherit searchable from parent config or buffer config)
      local is_searchable = buf_cfg.searchable or config.searchable
      local buf_id = create_term_buffer(buf_name, buf_cfg.cmd, is_searchable)
      register_buffer(prefix, sub_name, buf_id, buf_cfg)

      if buf_cfg.main then
        main_buf = buf_id
        created_main = true
      else
        -- Switch back to original buffer (don't hide - causes error on last window)
        vim.api.nvim_set_current_buf(original_buf)
      end
    end
  end

  -- Show the main buffer
  if main_buf then
    vim.api.nvim_set_current_buf(main_buf)
  end

  return main_buf
end

-- Create a custom terminal with environment variables (for :Terminal command)
function M.custom_terminal()
  vim.cmd('enew')

  vim.fn.termopen('pwsh', {
    env = {
      VIM_SERVERNAME = vim.v.servername or 'VIMSERVER',
      VIM_LISTEN_ADDRESS = vim.v.servername
    }
  })

  vim.schedule(function()
    vim.bo.syntax = ''
    vim.wo.signcolumn = 'no'
    vim.wo.spell = false
  end)
end

-- Legacy compatibility functions
function M.create_named_terminal(name, cmd, mode)
  mode = mode or "background"

  if not Terminal then
    vim.notify("Terminal class not initialized", vim.log.levels.ERROR)
    return
  end

  local term_opts = {
    cmd = cmd,
    close_on_exit = false,
    hidden = (mode == "background"),
    display_name = name,
    direction = mode == "tab" and "tab" or
                mode == "vsplit" and "vertical" or "horizontal"
  }

  local term = Terminal:new(term_opts)

  if mode == "background" then
    term:open()
    term:close()
  else
    term:open()
    if mode == "current" then
      vim.cmd('only')
    end
  end

  return term
end

function M.toggle_named_terminal(name)
  local entry = buffer_registry[name]
  if entry and buffer_valid(entry.buf_id) then
    vim.api.nvim_set_current_buf(entry.buf_id)
  else
    vim.notify("Terminal '" .. name .. "' does not exist", vim.log.levels.WARN)
  end
end

return M
