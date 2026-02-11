return {
    "folke/persistence.nvim",
    event = "BufReadPre", -- this will only start session saving when an actual file was opened
    opts = {
        -- add any custom options here
        dir = vim.fn.expand(vim.fn.stdpath("state") .. "/sessions/"), -- directory where session files are saved
        options = { "buffers", "curdir", "tabpages", "winsize" }, -- sessionoptions used for saving
        pre_save = nil, -- function to run before saving the session
    },
    keys = {
        -- add key mappings here
        { "<leader>qs", [[<cmd>lua require("persistence").load()<cr>]], desc = "Restore Session" },
        { "<leader>ql", [[<cmd>lua require("persistence").load({ last = true })<cr>]], desc = "Restore Last Session" },
        { "<leader>qd", [[<cmd>lua require("persistence").stop()<cr>]], desc = "Don't Save Current Session" },
    },
}
