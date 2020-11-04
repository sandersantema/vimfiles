local vcmd = vim.cmd
local vfn = vim.fn

vcmd('packadd packer.nvim')

local M = {}

local deps = {
  {'wbthomason/packer.nvim'; opt = true};
  {'godlygeek/tabular'; opt = true; cmd = {'Tabularize'}};
  {'junegunn/fzf.vim'; opt = true; cmd = {'FzfFiles'; 'FzfCommands'; 'FzfBuffers'; 'FzfLines'}};
  {'justinmk/vim-dirvish'};
  {
    'justinmk/vim-sneak';
    opt = true;
    keys = {
      {'n'; 's'};
      {'n'; 'S'};
      {'o'; 'z'};
      {'o'; 'Z'};
      {'n'; ';'};
      {'n'; ','};
      {'x'; ';'};
      {'x'; ','};
      {'o'; ';'};
      {'o'; ','};
    };
  };
  {'neovim/nvim-lspconfig'};
  {'nvim-lua/completion-nvim'; opt = true};
  {'sheerun/vim-polyglot'};
  {
    'tpope/vim-commentary';
    opt = true;
    keys = {{'n'; 'gcc'}; {'x'; 'gc'}; {'o'; 'gc'}; {'n'; 'gc'}};
  };
  {'tpope/vim-repeat'};
  {
    'tpope/vim-surround';
    opt = true;
    keys = {
      {'n'; 'gS'};
      {'n'; 'ds'};
      {'n'; 'cs'};
      {'n'; 'cS'};
      {'n'; 'ys'};
      {'n'; 'yS'};
      {'n'; 'yss'};
      {'n'; 'ySs'};
      {'x'; 'S'};
      {'x'; 'gS'};
    };
  };
  {
    'mattn/emmet-vim';
    opt = true;
    keys = {
      {'i'; '<C-X>m'};
      {'i'; '<C-X>A'};
      {'i'; '<C-X>a'};
      {'i'; '<C-X>k'};
      {'i'; '<C-X>j'};
      {'i'; '<C-X>/'};
      {'i'; '<C-X>I'};
      {'i'; '<C-X>i'};
      {'i'; '<C-X>N'};
      {'i'; '<C-X>n'};
      {'i'; '<C-X>D'};
      {'i'; '<C-X>d'};
      {'i'; '<C-X>u'};
      {'i'; '<C-X>;'};
      {'i'; '<C-X>,'};
    };
    cmd = {'Emmet'; 'EmmetInstall'};
  };
  {'rhysd/git-messenger.vim'; opt = true; cmd = {'GitMessenger'}; keys = {'<leader>gm'}};
  {'norcalli/nvim-colorizer.lua'};
  {'kana/vim-textobj-user'};
  {
    'thinca/vim-textobj-between';
    opt = true;
    keys = {{'x'; 'if'}; {'x'; 'af'}; {'o'; 'if'}; {'o'; 'af'}};
  };
  {'nvim-treesitter/nvim-treesitter'};
  {'nvim-treesitter/nvim-treesitter-textobjects'};
  {'nvim-treesitter/playground'; opt = true; cmd = {'TSPlaygroundToggle'}};
  {'romgrk/nvim-treesitter-context'; opt = true; cmd = {'TSContextEnable'}};
  {
    'michaeljsmith/vim-indent-object';
    opt = true;
    keys = {
      {'x'; 'ii'};
      {'x'; 'ai'};
      {'x'; 'iI'};
      {'x'; 'aI'};
      {'o'; 'ii'};
      {'o'; 'ai'};
      {'o'; 'iI'};
      {'o'; 'aI'};
    };
  };
}

local get_short_name = function(path)
  local parts = vim.split(path, '/', true)
  return parts[#parts]
end

local get_all_plugins = function()
  local result = {}
  local add_to_result = function(path)
    local short_name = get_short_name(path)
    result[short_name] = true
  end
  local plugin_utils = require('packer.plugin_utils')
  local opt_plugins, start_plugins = plugin_utils.list_installed_plugins()
  for k in pairs(opt_plugins) do
    add_to_result(k)
  end
  for k in pairs(start_plugins) do
    add_to_result(k)
  end
  return result
end

function M.install_and_wait(timeout_ms)
  local min_ms = 60000
  timeout_ms = timeout_ms or (2 * min_ms)
  require('packer').install()
  local status, _ = vim.wait(timeout_ms, function()
    local plugins = get_all_plugins()
    for _, dep in ipairs(deps) do
      local dep_short_name = get_short_name(dep[1])
      if not plugins[dep_short_name] then
        return false
      end
    end
    return true
  end, 100)
  if not status then
    error(string.format('PackerInstall timed out after %dms', timeout_ms))
  end
end

function M.reload()
  package.loaded['packed'] = nil
  require('packed').setup(true)
  require('packer').sync()
end

local setup_auto_commands = function()
  local helpers = require('lib.nvim_helpers')
  local fpath = vfn.stdpath('config') .. '/lua/packed.lua'
  helpers.augroup('packer-auto-sync', {
    {events = {'BufWritePost'}; targets = {fpath}; command = [[lua require('packed').reload()]]};
  })
end

local setup_sync_commands = function()
  vcmd([[command! -bar PackerInstallSync lua require('packed').install_and_wait()]])
end

function M.setup(reloading)
  require('packer').startup({deps; config = {compile_on_sync = true}})
  setup_auto_commands()
  setup_sync_commands()
  if not reloading then
    vim.schedule(function()
      vcmd([[doautocmd User PluginReady]])
    end)
  end
end

return M