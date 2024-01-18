local panelpal = require "panelpal"

local debug_const = require "lsp-config-loader.constant.debug"
local module_config = require "lsp-config-loader.config"

local LOG_MESSAGE_PANEL_NAME = debug_const.LOG_MESSAGE_PANEL_NAME
local LspLogLevel = debug_const.LspLogLevel

-- ----------------------------------------------------------------------------

local M = {}

local is_debug_on = false ---@type boolean
local old_log_message_handler = nil ---@type function?

-- ----------------------------------------------------------------------------

-- Sets LSP log level to `debug` and open a side panel for displaying LSP server"s
-- log message.
function M.lsp_server_debug_on()
    vim.lsp.set_log_level("debug")

    if is_debug_on then return end
    is_debug_on = true

    local old_handler = vim.lsp.handlers["window/logMessage"]
    old_log_message_handler = old_handler

    vim.lsp.handlers["window/logMessage"] = function(err, result, ctx, config)
        if old_handler then
            old_handler(err, result, ctx, config)
        end

        local buf, win = panelpal.find_buf_with_name(LOG_MESSAGE_PANEL_NAME)
        if not buf then
            buf, win = panelpal.set_panel_visibility(LOG_MESSAGE_PANEL_NAME, true)
        end
        if not (buf and win) then return end

        vim.bo[buf].buftype = "nofile"
        vim.bo[buf].modifiable = true

        local update_method = module_config.log_update_method() or panelpal.PanelContentUpdateMethod.append
        local log_level = LspLogLevel[result.type]

        panelpal.write_to_buf_with_highlight(
            buf, "LspLog" .. log_level,
            vim.fn.strftime("[%Y-%m-%d %X]") .. " Log Level: " .. log_level,
            update_method
        )
        panelpal.write_to_buf(buf, result.message, panelpal.PanelContentUpdateMethod.append)
        if win then
            local scroll_method = module_config.log_scroll_method() or panelpal.ScrollMethod.bottom
            -- offset 1 for log timestamp line
            panelpal.scroll_win(win, scroll_method, 1)
        end

        vim.bo[buf].modifiable = false
    end
end

-- Close log split window and set LSP log level to `warn`.
function M.lsp_server_debug_off()
    if not is_debug_on then return end

    panelpal.set_panel_visibility(LOG_MESSAGE_PANEL_NAME, false)
    vim.lsp.set_log_level("warn")
    vim.lsp.handlers["window/logMessage"] = old_log_message_handler
end

return M
