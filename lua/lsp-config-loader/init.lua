local command = require "lsp-config-loader.command"
local loader = require "lsp-config-loader.loader"
local module_config = require "lsp-config-loader.config"

local M = {}

-- Load setting table, and merge user config into lspconfig.
---@param option? table
function M.setup(option)
    if type(option) == "table" then
        for k, v in pairs(vim.deepcopy(option)) do
            module_config[k] = v
        end
    end

    command.init()

    loader.setup_lspconfig()
end

return M
