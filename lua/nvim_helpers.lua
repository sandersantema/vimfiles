local M = {}

function M.cmd_map(cmd)
  return string.format('<cmd>%s<cr>', cmd)
end

function M.create_mappings(mappings, bufnr)
  local fn = vim.api.nvim_set_keymap
  if bufnr then
    fn = function(...)
      vim.api.nvim_buf_set_keymap(bufnr, ...)
    end
  end

  for mode, rules in pairs(mappings) do
    for _, m in ipairs(rules) do
      fn(mode, m.lhs, m.rhs, m.opts or {})
    end
  end
end

function M.exec_cmds(cmd_list)
  vim.api.nvim_command(table.concat(cmd_list, '\n'))
end

return M
