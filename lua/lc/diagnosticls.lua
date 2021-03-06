local M = {}

local vfn = vim.fn

local default_root_patterns = {'.git'}

local setup_blackd_logs_dir = function(base_dir)
  local process = require('environ.process')
  local logs_dir = base_dir .. '/blackd-logs'
  vfn.mkdir(logs_dir, 'p')
  process.ENV.BLACKD_LOGS_DIR = logs_dir
end

local get_python_tool = function(bin_name)
  local result = bin_name
  if os.getenv('VIRTUAL_ENV') then
    local venv_bin_name = os.getenv('VIRTUAL_ENV') .. '/bin/' .. bin_name
    if vfn.executable(venv_bin_name) == 1 then
      result = venv_bin_name
    end
  end
  return result
end

local get_black = function()
  local nvim_config_path = vfn.stdpath('config')
  local bin = nvim_config_path .. '/langservers/bin/blackd-format'
  return {command = bin; rootPatterns = {'.git'; ''}}
end

local get_isort = function()
  return {
    command = get_python_tool('isort');
    args = {'-'};
    rootPatterns = {'.isort.cfg'; '.git'; ''};
  }
end

local get_flake8 = function()
  return {
    command = get_python_tool('flake8');
    args = {'--stdin-display-name'; '%filepath'; '-'};
    sourceName = 'flake8';
    debounce = 250;
    formatLines = 1;
    formatPattern = {'^[^:]+:(\\d+):((\\d+):)?\\s+(.+)$'; {line = 1; column = 3; message = 4}};
    rootPatterns = {'.flake8'; '.git'; ''};
  }
end

local get_add_trailing_comma = function()
  return {
    command = get_python_tool('add-trailing-comma');
    args = {'--exit-zero-even-if-changed'; '-'};
    rootPatterns = default_root_patterns;
  }
end

local get_reorder_python_imports = function()
  return {
    command = get_python_tool('reorder-python-imports');
    args = {'--exit-zero-even-if-changed'; '-'};
    rootPatterns = default_root_patterns;
  }
end

local get_autopep8 = function()
  return {
    command = get_python_tool('autopep8');
    args = {'-'};
    rootPatterns = default_root_patterns;
  }
end

local get_buildifier = function()
  local nvim_config_path = vfn.stdpath('config')
  local bin = nvim_config_path .. '/langservers/bin/buildifierw'
  if vfn.executable('buildifier') == 1 then
    return {command = bin; args = {'%filepath'}; rootPatterns = default_root_patterns}
  end
  return {}
end

local get_dune = function()
  return {command = 'dune'; args = {'format-dune-file'}; rootPatterns = default_root_patterns}
end

local get_shellcheck = function()
  return {
    command = 'shellcheck';
    args = {'-f'; 'gcc'; '-'};
    sourceName = 'shellcheck';
    debounce = 250;
    formatLines = 1;
    formatPattern = {
      '^[^:]+:(\\d+):(\\d+):\\s+([^:]+):\\s+(.*)$';
      {line = 1; column = 2; message = 4; security = 3};
    };
    securities = {error = 'error'; warning = 'warning'; note = 'info'};
    rootPatterns = default_root_patterns;
  }
end

local get_shfmt = function()
  return {command = 'shfmt'; args = {'-'}; rootPatterns = default_root_patterns}
end

local get_luacheck = function()
  return {
    command = 'luacheck';
    args = {'--formatter'; 'plain'; '--filename'; '%filepath'; '-'};
    sourceName = 'luacheck';
    debounce = 250;
    formatLines = 1;
    formatPattern = {'^[^:]+:(\\d+):(\\d+):\\s+(.+)$'; {line = 1; column = 2; message = 3}};
    rootPatterns = default_root_patterns;
    requiredFiles = {'.luacheckrc'};
  }
end

local get_luaformat = function()
  return {
    command = 'lua-format';
    rootPatterns = default_root_patterns;
    requiredFiles = {'.lua-format'};
  }
end

local read_precommit_config = function(file_path)
  local lyaml = require('lyaml')
  local f = io.open(file_path, 'r')
  local content = f:read('all*')
  f:close()
  return lyaml.load(content)
end

local blackd_cleanup_if_needed = function(init_options)
  for _, tools in pairs(init_options.formatFiletypes) do
    for _, tool in pairs(tools) do
      if tool == 'blackd' then
        require('lib.cleanup').register(function()
          local block = require('lib.cmd').run('pkill', {args = {'-f'; 'blackd'}}, nil, function()
          end)
          block(500)
        end)
        break
      end
    end
  end
end

local get_python_linters_and_formatters = function()
  local pre_commit_config_file_path = '.pre-commit-config.yaml'
  if vfn.filereadable(pre_commit_config_file_path) == 0 then
    return {flake8 = get_flake8()}, {
      add_trailing_comma = get_add_trailing_comma();
      blackd = get_black();
      isort = get_isort();
    }
  end

  local pc_linters_repo_map = {['https://gitlab.com/pycqa/flake8'] = {flake8 = get_flake8}}
  local pc_formatters_repo_map = {
    ['https://github.com/psf/black'] = {blackd = get_black};
    ['https://github.com/asottile/add-trailing-comma'] = {
      add_trailing_comma = get_add_trailing_comma;
    };
    ['https://github.com/asottile/reorder_python_imports'] = {
      reorder_python_imports = get_reorder_python_imports;
    };
    ['https://github.com/pre-commit/mirrors-autopep8'] = {autopep8 = get_autopep8};
    ['https://github.com/pre-commit/mirrors-isort'] = {isort = get_isort};
  }
  local local_repos_mapping = {['black'] = 'https://github.com/psf/black'}
  local pre_commit_config = read_precommit_config(pre_commit_config_file_path)
  local linters = {}
  local formatters = {}
  for _, repo in ipairs(pre_commit_config.repos) do
    local repo_url = repo.repo
    -- special case for black repo, but kinda setup to work with other tools
    -- too.
    if repo.repo == 'local' then
      -- should we loop through?
      if repo.hooks[1] then
        repo_url = local_repos_mapping[repo.hooks[1].id]
      end
    end
    local t = pc_linters_repo_map[repo_url]
    if t ~= nil then
      for k, fn in pairs(t) do
        linters[k] = fn()
      end
    end

    t = pc_formatters_repo_map[repo_url]
    if t ~= nil then
      for k, fn in pairs(t) do
        formatters[k] = fn()
      end
    end
  end

  return linters, formatters
end

local get_lua_linters_and_formatters = function()
  local linters = {luacheck = get_luacheck()}
  local formatters = {}
  if vfn.filereadable('.lua-format') ~= 0 then
    formatters.luaformat = get_luaformat()
  end
  return linters, formatters
end

local add_linters_and_formatters = function(init_options, ft, linters, formatters)
  init_options.linters = vim.tbl_extend('keep', init_options.linters or {}, linters)
  init_options.formatters = vim.tbl_extend('keep', init_options.formatters or {}, formatters)

  if init_options.filetypes == nil then
    init_options.filetypes = {}
  end

  if init_options.formatFiletypes == nil then
    init_options.formatFiletypes = {}
  end

  local ft_linters = init_options.filetypes[ft] or {}
  local ft_formatters = init_options.formatFiletypes[ft] or {}

  for tool in pairs(linters) do
    table.insert(ft_linters, tool)
  end
  init_options.filetypes[ft] = ft_linters

  for tool in pairs(formatters) do
    table.insert(ft_formatters, tool)
  end
  init_options.formatFiletypes[ft] = ft_formatters
end

local filter_empty = function(t)
  for k, v in pairs(t) do
    if vim.tbl_isempty(v) then
      t[k] = nil
    end
  end
  return t
end

local get_init_options = function()
  local init_options = {}

  local py_linters, py_formatters = get_python_linters_and_formatters()
  add_linters_and_formatters(init_options, 'python', py_linters, py_formatters)
  blackd_cleanup_if_needed(init_options)

  add_linters_and_formatters(init_options, 'sh', {shellcheck = get_shellcheck()},
                             {shfmt = get_shfmt()})
  add_linters_and_formatters(init_options, 'dune', {}, {dune = get_dune()})
  add_linters_and_formatters(init_options, 'bzl', {}, {buildifier = get_buildifier()})

  local lua_linters, lua_formatters = get_lua_linters_and_formatters()
  add_linters_and_formatters(init_options, 'lua', lua_linters, lua_formatters)
  init_options.filetypes = filter_empty(init_options.filetypes)
  init_options.formatFiletypes = filter_empty(init_options.formatFiletypes)
  return filter_empty(init_options)
end

function M.gen_config()
  local cache_dir = vfn.stdpath('cache')
  setup_blackd_logs_dir(cache_dir)

  local init_options = get_init_options()
  local fts = vim.tbl_keys(init_options.filetypes)
  for ft in pairs(init_options.formatFiletypes) do
    if init_options.filetypes[ft] == nil then
      table.insert(fts, ft)
    end
  end
  return init_options, fts
end

return M
