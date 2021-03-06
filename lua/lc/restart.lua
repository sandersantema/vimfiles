local M = {}

function M.stop()
  vim.lsp.stop_client(vim.lsp.get_active_clients())
  require('lc.formatting').reset()
end

function M.restart()
  M.stop()
  vim.cmd([[e!]])
end

return M
