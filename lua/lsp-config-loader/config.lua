local default_root = vim.fn.stdpath("config")
if type(default_root) == "table" then
    default_root = default_root[1]
end

---@class lsp-config-loader.ServerSpec
---@field [1] string # server name
---@field enabled boolean

local M = {
    -- LSP configuration root directory
    ---@type string
    root_path = default_root,
    -- LSP debug mode log content display method
    log_update_method = "append",
    log_scroll_method = "bottom",
    -- Whether to turn on inlay hint feature when a buffer is attached to LSP
    -- client.
    -- Can be either a boolean value or a function that takes client object and
    -- buffer number then returns a boolean.
    -- This option does noting when language server does not support inlay hint.
    ---@type boolean | fun(client: vim.lsp.Client, bufnr: integer): boolean
    use_inlay_hint = false,
    -- On attach callbask listed here will be called after keymap setup, and
    -- before on_attach in server specific config gets call.
    -- These callbacks apply to all client.
    ---@type (fun(client: vim.lsp.Client, bufnr: integer))[]
    on_attach_callbacks = {},
    -- Capability tables or functions that return capability table.
    -- Capability here will be merged into NeoVim's default capability.
    ---@type (table | fun(): table)[]
    capabilities_settings = {},
    -- Keybinding table, keys are input key, values are keys to be mapped to or
    -- callback functions.
    ---@type table<string, string | fun()>
    keymap = {},
    -- Server specific configs, keys are server name, values are config table or
    -- functions which return config table.
    -- Configuration value provided here will be merge into configs in config
    -- directory, and override options value in them.
    ---@type table<string, table>
    server_config = {},
    -- List of server names that should be setup with nvim-lspconfig.
    ---@type (string | lsp-config-loader.ServerSpec)[]
    server_list = {},
}

return M
