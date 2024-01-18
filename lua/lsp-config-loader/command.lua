local debug_util = require "lsp-config-loader.util.debug"

local cmd = vim.api.nvim_create_user_command

-- ----------------------------------------------------------------------------

local M = {}

local is_initialized = false

---@class lsp-config-loader.command.CommandInfo
---@field name string
---@field desc string
---@field callback fun()

---@type lsp-config-loader.command.CommandInfo[]
local cmd_list = {
    {
        name = "LspDebugOn",
        callback = debug_util.lsp_server_debug_on,
        desc = "turn on debug mode for LSP",
    },
    {
        name = "LspDebugOff",
        callback = debug_util.lsp_server_debug_off,
        desc = "turn off debug mode for LSP",
    },
}

function M.init()
    if is_initialized then return end

    is_initialized = true

    for _, info in ipairs(cmd_list) do
        cmd(info.name, info.callback, { desc = info.desc })
    end
end

return M
