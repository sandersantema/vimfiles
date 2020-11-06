local api = vim.api
local nvim_set_keymap = api.nvim_set_keymap
local vcmd = vim.cmd
local vfn = vim.fn

local initial_mappings = function()
  -- Disable ex mode. I'm not that smart.
  nvim_set_keymap('n', 'Q', '', {})

  -- Remap the leader key.
  nvim_set_keymap('n', '<Space>', '', {})
  vim.g.mapleader = ' '
  vim.g.maplocalleader = ' '

  -- Remap terminal escaping
  nvim_set_keymap('t', [[<c-\><c-\>]], [[<c-\><c-n>]], {})
end

local bootstrap_env = function()
  local process = require('environ.process')
  process.ENV.NVIM_CACHE_DIR = vfn.stdpath('cache')
end

local py3_editor_venv = function()
  local process = require('environ.process')
  local vim_venv_bin = vfn.stdpath('cache') .. '/venv/bin'
  process.ENV.PATH = string.format('%s:%s', vim_venv_bin, process.ENV.PATH)
end

local hererocks = function()
  local lua_version = string.gsub(_VERSION, 'Lua ', '')
  local hererocks_path = vfn.stdpath('cache') .. '/hr'
  local bin_path = hererocks_path .. '/bin'
  local share_path = hererocks_path .. '/share/lua/' .. lua_version
  local lib_path = hererocks_path .. '/lib/lua/' .. lua_version
  package.path = package.path .. ';' .. share_path .. '/?.lua' .. ';' .. share_path ..
                   '/?/init.lua'
  package.cpath = package.cpath .. ';' .. lib_path .. '/?.so'
  local process = require('environ.process')
  process.ENV.PATH = string.format('%s:%s', bin_path, process.ENV.PATH)
end

local global_vars = function()
  vim.g.netrw_home = vfn.stdpath('data')
  vim.g.netrw_banner = 0
  vim.g.netrw_liststyle = 3
  vim.g.fzf_command_prefix = 'Fzf'
  vim.g.fzf_height = '80%'
  vim.g.polyglot_disabled = {'markdown'; 'sensible'; 'autoindent'}
  vim.g.user_emmet_mode = 'i'
  vim.g.user_emmet_leader_key = [[<C-x>]]
end

local ui_options = function()
  vim.o.termguicolors = true
  vim.o.showcmd = false
  vim.o.laststatus = 0
  vim.o.ruler = true
  vim.o.rulerformat = [[%-14.(%l,%c   %o%)]]
  vim.o.guicursor = ''
  vim.o.mouse = ''
  vim.o.shortmess = 'filnxtToOFIc'
  require('color').setup()
end

local global_options = function()
  vim.o.completeopt = 'menuone,noinsert,noselect'
  vim.o.hidden = true
  vim.o.backspace = 'indent,eol,start'
  vim.o.hlsearch = false
  vim.o.incsearch = true
  vim.o.smartcase = true
  vim.o.wildmenu = true
  vim.o.wildmode = 'list:longest'
  vim.o.autoindent = true
  vim.o.smartindent = true
  vim.o.smarttab = true
  vim.o.errorbells = false
  vim.o.backup = false
  vim.o.swapfile = false
  vim.o.inccommand = 'split'
  vim.o.timeoutlen = 500
  vim.o.jumpoptions = 'stack'
end

local rnu = function()
  vcmd('set relativenumber')
end

local folding = function()
  local helpers = require('lib.nvim_helpers')
  local fold_method = 'indent'
  vim.o.foldlevelstart = 99
  vim.wo.foldmethod = fold_method
  vim.schedule(function()
    helpers.augroup('folding_config', {
      {events = {'BufEnter'}; targets = {'*'}; command = [[setlocal foldmethod=]] .. fold_method};
    })
  end)
end

local global_mappings = function()
  local helpers = require('lib.nvim_helpers')
  local rl_bindings = {
    {lhs = '<c-a>'; rhs = '<home>'; opts = {noremap = true}};
    {lhs = '<c-e>'; rhs = '<end>'; opts = {noremap = true}};
    {lhs = '<c-f>'; rhs = '<right>'; opts = {noremap = true}};
    {lhs = '<c-b>'; rhs = '<left>'; opts = {noremap = true}};
    {lhs = '<c-p>'; rhs = '<up>'; opts = {noremap = true}};
    {lhs = '<c-n>'; rhs = '<down>'; opts = {noremap = true}};
    {lhs = '<c-d>'; rhs = '<del>'; opts = {noremap = true}};
  }
  local maps = {
    n = {
      {lhs = '<leader>o'; rhs = helpers.cmd_map('only')};
      {lhs = '<leader>O'; rhs = helpers.cmd_map('only') .. helpers.cmd_map('tabonly')};
      {
        lhs = 'j';
        rhs = [[(v:count > 8 ? "m'" . v:count : '') . 'j']];
        opts = {expr = true; noremap = true};
      };
      {
        lhs = 'k';
        rhs = [[(v:count > 8 ? "m'" . v:count : '') . 'k']];
        opts = {expr = true; noremap = true};
      };
    };
    i = {{lhs = '<c-d>'; rhs = '<del>'; opts = {noremap = true}}};
    c = rl_bindings;
    o = rl_bindings;
  }

  local win_mov_keys = {'h'; 'j'; 'k'; 'l'}
  require('lib.fun_wrapper').iter(win_mov_keys):each(
    function(key)
      table.insert(maps.n, {lhs = '<leader>' .. key; rhs = helpers.cmd_map('wincmd ' .. key)})
    end)
  helpers.create_mappings(maps)
end

do
  local schedule = vim.schedule
  initial_mappings()
  hererocks()
  bootstrap_env()

  schedule(function()
    global_options()
    global_mappings()
  end)

  ui_options()
  rnu()
  folding()
  global_vars()
  py3_editor_venv()

  require('packed').setup()
  if not os.getenv('NVIM_BOOTSTRAP') then
    schedule(function()
      require('plugin.init')
    end)
  end
end
