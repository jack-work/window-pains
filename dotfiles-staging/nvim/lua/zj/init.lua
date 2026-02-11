local M = {}

function M.create_note()
  local notes_dir = os.getenv("zjnotes")

  if not notes_dir then
    vim.notify("Environment variable 'zjnotes' not found!", vim.log.levels.ERROR)
    return
  end

  -- Prompt user for filename
  vim.ui.input({
    prompt = "Enter note name: ",
  }, function(input)
    local date = os.date("%Y-%m-%d")
    local filename = input

    if not filename or filename == "" then
      filename = date .. ".md"
    elseif not filename:match("%.md$") then
      filename = filename .. ".md"
    end

    local full_path = vim.fs.normalize(vim.fs.joinpath(notes_dir, filename))

    -- Create the file
    local file = io.open(full_path, "w")
    vim.notify("Attempting create note in: " .. full_path);
    if file then
      file:write("# " .. os.date("%Y-%m-%d %A") .. "\n\n")
      file:close()
      -- Open the file in a new split
      vim.cmd("split " .. full_path)
    else
      vim.notify("Failed to create note file!", vim.log.levels.ERROR)
    end
  end)
end

function M.setup()
  -- Create keybindings
  vim.keymap.set("n", "<leader>jz", M.create_note, { desc = "Create new note" })
  -- todo: replace with fzf lua
  -- vim.keymap.set("n", "<leader>js", M.search_note, { desc = "Search notes" })
  -- vim.keymap.set("n", "<leader>jg", M.grep_notes, { desc = "Grep notes" })
end

return M
