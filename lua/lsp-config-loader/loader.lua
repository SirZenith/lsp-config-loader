local lsp_status_ok, lsp_status = pcall(require, "lsp-status")
if not lsp_status_ok then
    lsp_status = nil
end

local fs = vim.fs

local module_config = require "lsp-config-loader.config"

local M = {}

---@param client lsp.Client
---@param bufnr number
local function lsp_on_attach(client, bufnr)
    -- Enable completion triggered by <c-x><c-o>
    vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

    -- See `:help vim.lsp.*` for documentation on any one of following functions
    local keymap = {
        -- utility
        ["<A-F>"] = function() vim.lsp.buf.format(module_config.format_args) end,
        ["<F2>"] = vim.lsp.buf.rename,
        ["<space>ca"] = vim.lsp.buf.code_action,
        -- goto
        ["gd"] = vim.lsp.buf.definition,
        ["gD"] = vim.lsp.buf.declaration,
        ["gr"] = vim.lsp.buf.references,
        ["gi"] = vim.lsp.buf.implementation,
        -- diagnostic
        ["<A-n>"] = vim.diagnostic.goto_prev,
        ["<A-.>"] = vim.diagnostic.goto_next,
        ["<space>d"] = vim.diagnostic.setloclist,
        ["<space>e"] = vim.diagnostic.open_float,
        -- hover & detail
        ["K"] = vim.lsp.buf.hover,
        ["<C-k>"] = vim.lsp.buf.signature_help,
        ["<space>D"] = vim.lsp.buf.type_definition,
        -- workspace
        ["<space>wa"] = vim.lsp.buf.add_workspace_folder,
        ["<space>wr"] = vim.lsp.buf.remove_workspace_folder,
        ["<space>wl"] = function()
            local msg = table.concat(vim.lsp.buf.list_workspace_folders(), ",\n")
            vim.notify(msg)
        end,
    }

    local set = vim.keymap.set
    local opts = { noremap = true, silent = true, buffer = bufnr }
    for key, callback in pairs(keymap) do
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
        local ok, module = xpcall(function() return require(user_config_path) end, debug.traceback)
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
    local capabilities = {}
    for _, cap in ipairs(module_config.capabilities_settings) do
        vim.tbl_extend("force", capabilities, cap)
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

return M
