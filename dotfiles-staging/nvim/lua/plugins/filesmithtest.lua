return {
  dir = vim.fn.stdpath("config") .. "/lua/filesmith",
  keys = {
    {
      "<leader>cf",
      function()
        require("filesmith").create_file_with_code()
      end,
      desc = "Create file from code block"
    },
    {
      "<leader>ycl",
      function()
        require("filesmith").copy_cursor_location()
      end
    },
    {
      "<leader>yff",
      function()
        require("filesmith").copy_file_link()
      end
    },
  }
}
