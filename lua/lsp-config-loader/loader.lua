local config = require("lsp-config-loader.config")

local fs = vim.fs
local fnamemodify = vim.fn.fnamemodify

local module_config = require "lsp-config-loader.config"

local M = {}

---@param module_name string
---@return string[]
local function get_config_module_paths(module_name)
    return {
        fnamemodify(module_name, ":p"),
        fnamemodify(module_name .. ".lua", ":p"),
        fnamemodify(module_name .. "/init.lua", ":p"),
    }
end

-- load module with absolute path
local function require_absolute(module_name)
    local errmsg = { "" }
    local err_template = "no file '%s'"

    local paths = get_config_module_paths(module_name)

    for _, filename in ipairs(paths) do
        if vim.fn.filereadable(filename) == 1 then
            local file = io.open(filename, "rb")
            if file then
                local content = assert(file:read("*a"))
                return assert(loadstring(content, filename))
            end
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

-- Tries turning inlay hint on according to user setting.
---@param client vim.lsp.Client
---@param bufnr integer
local function try_turn_on_inlay_hint(client, bufnr)
    if not client.server_capabilities.inlayHintProvider then
        return
    end

    local checker = config.use_inlay_hint
    local checker_type = type(checker)

    local is_on = false
    if checker_type == "boolean" then
        is_on = checker
    elseif checker_type == "function" then
        is_on = checker(client, bufnr)
    end

    vim.lsp.inlay_hint.enable(is_on, { bufnr = bufnr })
end

---@param client vim.lsp.Client
---@param bufnr number
local function lsp_on_attach(client, bufnr)
    -- Enable completion triggered by <c-x><c-o>
    vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

    local set = vim.keymap.set
    local opts = { noremap = true, silent = true, buffer = bufnr }
    for key, callback in pairs(module_config.keymap) do
        set("n", key, callback, opts)
    end

    try_turn_on_inlay_hint(client, bufnr)

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
    local ls_config = {
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
    ls_config.capabilities = capabilities

    -- merging
    ls_config = vim.tbl_deep_extend(
        "force",
        ls_config,
        load_config_from_module(ls_name),
        user_config or {}
    )

    -- wrapping on_attach
    local on_attach = ls_config.on_attach
    ls_config.on_attach = function(client, bufnr)
        lsp_on_attach(client, bufnr)

        if type(on_attach) == 'function' then
            on_attach(client, bufnr)
        end
    end

    return ls_config
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

            vim.lsp.enable(server)
            vim.lsp.config(server, user_config)
        end
    end
end

return M
