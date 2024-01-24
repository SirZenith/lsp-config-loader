local default_root = vim.fn.stdpath("config")
if type(default_root) == "table" then
    default_root = default_root[1]
end

local M = {
    root_path = default_root,
    log_update_method = "append",
    log_scroll_method = "bottom",
    on_attach_callbacks = {},
    capabilities_settings = {},
    format_args = {
        async = true
    },
    keymap = {},
    kind_label = {},
    server_config = {},
    server_list = {},
}

return M
