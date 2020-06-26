local vcmd = vim.cmd
local parsers = require('nvim-treesitter.parsers')

local wanted_parsers = {
  'bash'; 'css'; 'go'; 'html'; 'javascript'; 'json'; 'lua'; 'ocaml'; 'python'; 'rust'; 'tsx';
  'typescript'; 'cpp'; 'c';
};

local set_folding = function()
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

  vcmd([[augroup folding_config]])
  vcmd([[autocmd!]])
  vcmd(string.format([[autocmd FileType %s setlocal foldmethod=expr foldexpr=%s]],
                     table.concat(file_types, ','), foldexpr))
  vcmd([[augroup END]])
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
    ensure_installed = wanted_parsers;
  })
  set_folding()
  configs.commands.TSEnableAll.run('highlight')
  configs.commands.TSEnableAll.run('incremental_selection')
end