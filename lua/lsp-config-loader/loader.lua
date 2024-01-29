local lsp_status_ok, lsp_status = pcall(require, "lsp-status")
if not lsp_status_ok then
    lsp_status = nil
end

local lspconfig = require "lspconfig"

local fs = vim.fs
local fnamemodify = vim.fn.fnamemodify

local module_config = require "lsp-config-loader.config"

local M = {}

---@param module_name string
---@return string[]
local function get_config_module_paths(module_name)
    return {
        fnamemodify(module_name, ":p"),
        fnamemodify(module_name .. ".lua", ":p") ,
        fnamemodify(module_name .. "/init.lua", ":p"),
    }
end

-- load module with absolute path
local function require_absolute(module_name)
    local errmsg = { "" }
    local err_template = "no file '%s'"

    local paths = get_config_module_paths(module_name)

    for _, filename in ipairs(paths) do
        local file = io.open(filename, "rb")
        if file then
            local content = assert(file:read("*a"))
            return assert(loadstring(content, filename))
        end
        table.insert(errmsg, err_template:format(filename))
    end

    error(table.concat(errmsg, "\n\t"))
end

---@param module_name string
---@return boolean
local function check_config_module_exists(module_name)
    local paths = get_config_module_paths(module_name)
    local ok = false
    for _, path in ipairs(paths) do
        if vim.fn.filereadable(path) == 1 then
            ok = true
            break
        end
    end
    return ok
end

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
    local module_name = fs.normalize(module_config.root_path) .. "/" .. ls_name

    if not check_config_module_exists(module_name) then
        return {}
    end

    local ok, module = xpcall(
        require_absolute,
        function(err)
            local traceback = debug.traceback(err)
            vim.notify(traceback or err, vim.log.levels.WARN)
        end,
        module_name
    )

    local user_config
    if ok then
        user_config = module()
    else
        user_config = {}
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
        local cap_t = type(cap)
        if cap_t == "table" then
            capabilities = vim.tbl_extend("force", capabilities, cap)
        elseif cap_t == "function" then
            capabilities = vim.tbl_extend("force", capabilities, cap())
        end
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

---@param info string | lsp-config-loader.ServerSpec
---@return string
local function get_name(info)
    return type(info) == "string" and info or info[1]
end

function M.setup_lspconfig()
    for _, info in ipairs(module_config.server_list) do
        if info.enabled ~= false then
            local server = get_name(info)

            local user_config = module_config.server_config[server]
            if type(user_config) == "function" then
                user_config = user_config()
            end

            user_config = M.load(server, user_config)

            lspconfig[server].setup(user_config)
        end
    end
end

return M
