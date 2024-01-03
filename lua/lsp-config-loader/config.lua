local M = {
    root_path = vim.fn.stdpath("config"),
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
