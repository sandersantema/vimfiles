local parsers = require('nvim-treesitter.parsers')

local wanted_parsers = {
  'bash'; 'css'; 'go'; 'html'; 'javascript'; 'json'; 'ocaml'; 'rust'; 'tsx'; 'typescript'; 'cpp';
  'c'; 'yaml'; 'markdown'; 'lua'; 'python';
};

local set_folding = function()
  local helpers = require('lib.nvim_helpers')
  local file_types = {}
  for i, lang in ipairs(wanted_parsers) do
    file_types[i] = parsers.lang_to_ft(lang)
  end

  local foldexpr = 'nvim_treesitter#foldexpr()'

  for _, ft in pairs(file_types) do
    if ft == vim.bo.filetype then
      vim.wo.foldmethod = 'expr'
      vim.wo.foldexpr = foldexpr
    end
  end

  helpers.augroup('folding_config', {
    {
      events = {'FileType'};
      targets = file_types;
      command = [[setlocal foldmethod=expr foldexpr=]] .. foldexpr;
    };
  })
end

do
  local configs = require('nvim-treesitter.configs')
  configs.setup({
    highlight = {enable = true};
    incremental_selection = {
      enable = true;
      keymaps = {
        init_selection = 'gnn';
        node_incremental = '<tab>';
        scope_incremental = 'grc';
        node_decremental = '<s-tab>';
      };
    };
    refactor = {
      smart_rename = {enable = true; keymaps = {smart_rename = 'grr'}};
      navigation = {enable = true; keymaps = {goto_definition = 'gd'; list_defitinions = 'gnD'}};
    };
    ensure_installed = wanted_parsers;
  })
  set_folding()
  configs.commands.TSEnableAll.run('highlight')
  configs.commands.TSEnableAll.run('incremental_selection')
  configs.commands.TSEnableAll.run('refactor.smart_rename')
  configs.commands.TSEnableAll.run('refactor.navigation')
end
