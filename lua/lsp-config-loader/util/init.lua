local M = {}

---@param source string # diagnostic source name
function M.disable_diagnostic_source(source)
    vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(
        function(_, result, ctx, config)
            local messages = {}
            for _, diag in ipairs(result.diagnostics) do
                if diag.source ~= source then
                    table.insert(messages, diag)
                end
            end
            result.diagnostics = messages
            vim.lsp.diagnostic.on_publish_diagnostics(_, result, ctx, config)
        end,
        {}
    )
end

return M
