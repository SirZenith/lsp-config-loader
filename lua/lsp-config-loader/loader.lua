local lsp_status_ok, lsp_status = pcall(require, "lsp-status")
if not lsp_status_ok then
    lsp_status = nil
end

local lspconfig = require "lspconfig"

local fs = vim.fs

local module_config = require "lsp-config-loader.config"

local M = {}

---@param client lsp.Client
---@param bufnr number
local function lsp_on_attach(client, bufnr)
    -- Enable completion triggered by <c-x><c-o>
    vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

    local set = vim.keymap.set
    local opts = { noremap = true, silent = true, buffer = bufnr }
    for key, callback in pairs(module_config.keymap) do
        set("n", key, callback, opts)
    end

    for _, callback in ipairs(module_config.on_attach_callbacks) do
        callback(client, bufnr)
    end
end

-- Try to find config file for given language server in user config directory.
---@param ls_name string
local function load_config_from_module(ls_name)
    local user_config_path = fs.normalize(module_config.root_path) .. "/" .. ls_name .. ".lua"

    local user_config
    if vim.fn.filereadable(user_config_path) == 0 then
        user_config = {}
    else
        local ok, module = xpcall(function()
            return require(user_config_path)
        end, function(err)
            local thread = coroutine.running()
            local traceback = debug.traceback(thread, err)
            vim.notify(traceback or err, vim.log.levels.WARN)
        end)
        user_config = ok and module or {}
    end

    return user_config
end

-- Load config table for given language server. Resolve priority from low to high
-- will be: some basic default, config in user cnfig directory, workspace user
-- config.
---@param ls_name string
---@param user_config? table
---@return table
function M.load(ls_name, user_config)
    local config = {
        flags = {
            debounce_text_changes = 150,
        },
    }

    -- set capabilities
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    for _, cap in ipairs(module_config.capabilities_settings) do
        capabilities = vim.tbl_extend("force", capabilities, cap)
    end
    config.capabilities = capabilities

    -- lsp status plugin hook
    local ext = lsp_status and lsp_status.extensions[ls_name]
    if ext then
        config.handlers = ext.setup()
    end

    -- merging
    config = vim.tbl_extend(
        "force",
        config,
        load_config_from_module(ls_name),
        user_config or {}
    )

    -- wrapping on_attach
    local on_attach = config.on_attach
    config.on_attach = function(client, bufnr)
        lsp_on_attach(client, bufnr)

        if type(on_attach) == 'function' then
            on_attach(client, bufnr)
        end
    end

    return config
end

local function get_name(info)
    return type(info) == "string" and info or info[1]
end

function M.setup_lspconfig()
    for _, info in ipairs(module_config.server_list) do
        if info.enable ~= false then
            local server = get_name(info)

            local user_config = M.load(
                server,
                module_config.server_config[server]
            )

            lspconfig[server].setup(user_config)
        end
    end
end

return M
