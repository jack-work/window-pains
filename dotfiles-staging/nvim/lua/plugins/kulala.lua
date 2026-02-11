return {
  "mistweaverco/kulala.nvim",
  keys = {
    { "<leader>Rs", desc = "Send request" },
    { "<leader>Ra", desc = "Send all requests" },
    { "<leader>Rb", desc = "Open scratchpad" },
    {
      "<leader>Rv",
      function()
        -- Helper function to find and parse http-client.env.json
        local function get_env_data()
          local current_file = vim.api.nvim_buf_get_name(0)
          local current_dir = vim.fn.fnamemodify(current_file, ':p:h')
          local config_file = vim.fn.findfile('http-client.env.json', current_dir .. ';')

          if config_file == '' then
            return nil, nil, "http-client.env.json not found in ancestor directories"
          end

          local file = io.open(config_file, 'r')
          if not file then
            return nil, nil, "Could not open file: " .. config_file
          end

          local content = file:read('*all')
          file:close()

          local ok, data = pcall(vim.fn.json_decode, content)
          if not ok then
            return nil, nil, "Failed to parse JSON: " .. tostring(data)
          end

          return data, config_file, nil
        end

        -- Step 1: Load the environment file
        local data, config_file, err = get_env_data()
        if err then
          vim.notify(err, vim.log.levels.ERROR)
          return
        end

        -- Step 2: Collect all unique variable names (second-level properties)
        local variable_names = {}
        local seen = {}
        for env_name, env_vars in pairs(data) do
          if type(env_vars) == 'table' and not env_name:match('^%$') then
            for var_name, _ in pairs(env_vars) do
              if not seen[var_name] then
                seen[var_name] = true
                table.insert(variable_names, var_name)
              end
            end
          end
        end

        if #variable_names == 0 then
          vim.notify("No variables found in environments", vim.log.levels.WARN)
          return
        end

        table.sort(variable_names)

        -- Step 3: Single-select variable name with fzf-lua
        require('fzf-lua').fzf_exec(variable_names, {
          prompt = 'Select Variable Name > ',
          actions = {
            ['default'] = function(selected_vars)
              if not selected_vars or #selected_vars == 0 then
                return
              end

              local selected_var = selected_vars[1]

              -- Step 4: Get all environment names (first-level properties)
              local environments = {}
              for key, value in pairs(data) do
                if type(value) == 'table' and not key:match('^%$') then
                  table.insert(environments, key)
                end
              end
              table.sort(environments)

              -- Step 5: Multi-select environments with fzf-lua
              require('fzf-lua').fzf_exec(environments, {
                prompt = 'Select Environments (TAB to multi-select) > ',
                fzf_opts = {
                  ['--multi'] = '',
                  ['--bind'] = 'tab:toggle+down',
                },
                actions = {
                  ['default'] = function(selected_envs)
                    if not selected_envs or #selected_envs == 0 then
                      return
                    end

                    -- Step 6: Prompt for new value
                    vim.ui.input({
                      prompt = string.format('Enter value for "%s": ', selected_var),
                    }, function(new_value)
                      if not new_value then
                        vim.notify("Operation cancelled", vim.log.levels.INFO)
                        return
                      end

                      -- Step 7: Update the JSON data
                      for _, env in ipairs(selected_envs) do
                        if not data[env] then
                          data[env] = {}
                        end
                        data[env][selected_var] = new_value
                      end

                      -- Step 8: Write back to file with pretty formatting
                      local json_str = vim.fn.json_encode(data)

                      -- Pretty print the JSON (basic formatting)
                      -- Note: This uses jq if available, otherwise uses compact format
                      local formatted_json
                      local jq_available = vim.fn.executable('jq') == 1

                      if jq_available then
                        local temp_file = vim.fn.tempname()
                        local f = io.open(temp_file, 'w')
                        if f then
                          f:write(json_str)
                          f:close()
                          formatted_json = vim.fn.system('jq . ' .. vim.fn.shellescape(temp_file))
                          vim.fn.delete(temp_file)
                        else
                          formatted_json = json_str
                        end
                      else
                        formatted_json = json_str
                      end

                      local write_file = io.open(config_file, 'w')
                      if not write_file then
                        vim.notify("Could not write to file: " .. config_file, vim.log.levels.ERROR)
                        return
                      end

                      write_file:write(formatted_json)
                      write_file:close()

                      vim.notify(
                        string.format(
                          'Updated "%s" in %d environment(s): %s',
                          selected_var,
                          #selected_envs,
                          table.concat(selected_envs, ', ')
                        ),
                        vim.log.levels.INFO
                      )
                    end)
                  end
                }
              })
            end
          }
        })
      end,
      desc = "Set environment variable value"
    },
    {
      "<leader>Re",
      function()
        local function get_envs()
          -- Get the directory of the current buffer
          local current_file = vim.api.nvim_buf_get_name(0)
          local current_dir = vim.fn.fnamemodify(current_file, ':p:h')

          -- Search for http-client.env.json in ancestor directories
          local config_file = vim.fn.findfile('http-client.env.json', current_dir .. ';')

          if config_file == '' then
            return nil, "http-client.env.json not found in ancestor directories"
          end

          -- Read and parse the JSON file
          local file = io.open(config_file, 'r')
          if not file then
            return nil, "Could not open file: " .. config_file
          end

          local content = file:read('*all')
          file:close()

          -- Parse JSON
          local ok, data = pcall(vim.fn.json_decode, content)
          if not ok then
            return nil, "Failed to parse JSON: " .. tostring(data)
          end

          -- Extract top-level keys that don't start with $
          local environments = {}
          for key, _ in pairs(data) do
            if type(key) == 'string' and not key:match('^%$') then
              table.insert(environments, key)
            end
          end
          return environments, nil
        end

        local envs, err = get_envs()
        if err then
          vim.notify(err, vim.log.levels.ERROR)
        end

        require('fzf-lua').fzf_exec(envs, {
          prompt = 'Select HTTP Client Environment > ',
          actions = {
            ['default'] = function(selected)
              if selected and #selected > 0 then
                -- Do something with the selected environment
                vim.notify("Selected environment: " .. selected[1], vim.log.levels.INFO)
                require('kulala').set_selected_env(selected[1])
              end
            end
          }
        })
      end,
      desc = "Select http environment"
    }
  },
  ft = { "http", "rest" },
  opts = {
    global_keymaps = true,
    global_keymaps_prefix = "<leader>R",
    kulala_keymaps_prefix = "",
  },
}
