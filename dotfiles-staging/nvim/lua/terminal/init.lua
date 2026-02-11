-- Terminal plugin initialization
-- Generic library that receives ALL config via opts parameter

local M = {}
local terminals_lib = require('terminal.terminals')

function M.setup(opts)
  opts = opts or {}

  -- Load toggleterm
  local status, toggleterm = pcall(require, 'toggleterm')
  if not status then
    vim.notify("toggleterm not found", vim.log.levels.ERROR)
    return
  end

  -- Configure shell if provided
  if opts.shell then
    vim.cmd("let &shell = " .. opts.shell.shell)
    vim.cmd("let &shellcmdflag = '" .. opts.shell.shellcmdflag .. "'")
    vim.cmd("let &shellredir = '" .. opts.shell.shellredir .. "'")
    vim.cmd("let &shellpipe = '" .. opts.shell.shellpipe .. "'")
    vim.cmd("set shellquote=" .. (opts.shell.shellquote or '') .. " shellxquote=" .. (opts.shell.shellxquote or ''))
  end

  -- Setup toggleterm with provided options
  if opts.toggleterm then
    toggleterm.setup(opts.toggleterm)
  end

  -- Get Terminal class and pass to terminals library
  local Terminal = require('toggleterm.terminal').Terminal
  terminals_lib.set_terminal_class(Terminal)

  -- Store toggleterm instances for single-process terminals
  local toggleterm_instances = {}

  -- Process polymorphic terminals list
  if opts.terminals then
    for _, term_config in ipairs(opts.terminals) do
      if not term_config.name or not term_config.keymap then
        vim.notify("Terminal config missing required 'name' or 'keymap'", vim.log.levels.WARN)
        goto continue
      end

      local is_multi = term_config.buffers ~= nil

      if is_multi then
        -- Multi-process terminal: create keymap that invokes invoke_multi
        vim.keymap.set("n", term_config.keymap, function()
          terminals_lib.invoke_multi(term_config)
        end, {
          desc = term_config.desc or ("Start " .. term_config.name)
        })
      else
        -- Single-process terminal: create toggleterm instance
        local term_opts = {
          cmd = term_config.cmd,
          direction = term_config.direction or "float",
          close_on_exit = term_config.close_on_exit ~= false,
          start_in_insert = term_config.start_in_insert ~= false,
          display_name = term_config.name,
        }

        if term_config.float_opts then
          term_opts.float_opts = term_config.float_opts
        end

        -- Set up on_open handler for searchable and use_ctrl options
        term_opts.on_open = function(term)
          -- searchable = true means buffer is listed (shows in buffer pickers)
          vim.bo[term.bufnr].buflisted = term_config.searchable or false
          -- Ctrl-q to close (if use_ctrl)
          if term_config.use_ctrl then
            local kopts = { buffer = term.bufnr, noremap = true, silent = true }
            vim.keymap.set('t', '<C-q>', [[<C-\><C-n>:q<CR>]], kopts)
          end
        end

        local instance = Terminal:new(term_opts)
        toggleterm_instances[term_config.name] = instance

        -- Create keymap
        vim.keymap.set("n", term_config.keymap, function()
          if term_config.singleton == false then
            -- Non-singleton: create new instance each time
            terminals_lib.invoke_single(term_config, nil)
          else
            -- Singleton (default): toggle existing instance
            instance:toggle()
          end
        end, {
          desc = term_config.desc or ("Toggle " .. term_config.name)
        })

        -- Store globally for compatibility
        _G['_TOGGLE_' .. term_config.name:upper()] = function()
          instance:toggle()
        end
      end

      ::continue::
    end
  end

  -- Process custom keymaps if provided
  if opts.custom_keymaps then
    for _, keymap_config in ipairs(opts.custom_keymaps) do
      vim.keymap.set(
        keymap_config.mode or "n",
        keymap_config.keymap,
        keymap_config.action,
        { desc = keymap_config.desc }
      )
    end
  end

  -- Override :terminal command if requested
  if opts.override_terminal ~= false then
    vim.api.nvim_create_user_command('Terminal', terminals_lib.custom_terminal, {
      nargs = 0,
      force = true
    })
    vim.cmd('cabbrev terminal Terminal')
  end

  -- Expose for backward compatibility
  _G.create_named_terminal = terminals_lib.create_named_terminal
  _G.toggle_named_terminal = terminals_lib.toggle_named_terminal
end

return M
