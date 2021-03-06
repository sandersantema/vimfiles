local api = vim.api
local themes = require('themes')

local M = {}

local _default_theme

local _themes = {}

function M.set_popup_winid(winid)
  _themes[winid] = themes.popup
end

function M.set_default_theme(theme_ns)
  _default_theme = theme_ns
end

function M.setup()
  vim.o.background = 'light'
  _default_theme = themes.none
  local cb = function(_, winid)
    local theme = _themes[winid] or _default_theme
    api.nvim_set_hl_ns(theme)
  end
  api.nvim_set_decoration_provider(themes.none, {on_win = cb; on_line = cb})
end

return M
