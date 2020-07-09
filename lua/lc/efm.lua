local M = {}

local vfn = vim.fn
local loop = vim.loop

local created_files = {}

local setup_blackd_logs_dir = function(base_dir)
  local logs_dir = base_dir .. '/blackd-logs'
  vfn.mkdir(logs_dir, 'p')
  loop.os_setenv('BLACKD_LOGS_DIR', logs_dir)
end

local get_python_tool = function(bin_name)
  local result = bin_name
  if loop.os_getenv('VIRTUAL_ENV') then
    local venv_bin_name = loop.os_getenv('VIRTUAL_ENV') .. '/bin/' .. bin_name
    if vfn.executable(venv_bin_name) == 1 then
      result = venv_bin_name
    end
  end
  return result
end

local get_dmypy = function()
  return {
    ['lint-command'] = string.format('%s run', get_python_tool('dmypy'));
    ['lint-formats'] = {'%f:%l: %trror: %m'; '%f:%l: %tarning: %m'; '%f:%l: %tote: %m'};
  }
end

local get_black = function()
  local nvim_config_path = vfn.stdpath('config')
  local bin = nvim_config_path .. '/langservers/bin/blackd-format'
  return {['format-command'] = bin; ['format-stdin'] = true}
end

local get_isort = function()
  return {
    ['format-command'] = string.format('%s -', get_python_tool('isort'));
    ['format-stdin'] = true;
  }
end

local get_flake8 = function()
  return {
    ['lint-command'] = string.format('%s --stdin-display-name ${INPUT} -',
                                     get_python_tool('flake8'));
    ['lint-stdin'] = true;
    ['lint-formats'] = {[[%f:%l:%c: %m]]};
  }
end

local get_add_trailing_comma = function()
  return {
    ['format-command'] = string.format('%s -', get_python_tool('add-trailing-comma'));
    ['format-stdin'] = true;
  }
end

local get_reorder_python_imports = function()
  return {
    ['format-command'] = string.format('%s -', get_python_tool('reorder-python-imports'));
    ['format-stdin'] = true;
  }
end

local get_autopep8 = function()
  return {
    ['format-command'] = string.format('%s -', get_python_tool('autopep8'));
    ['format-stdin'] = true;
  }
end

local get_dune = function()
  return {['format-command'] = 'dune format-dune-file'; ['format-stdin'] = true}
end

local get_shellcheck = function()
  return {
    ['lint-command'] = 'shellcheck -f gcc -x';
    ['lint-formats'] = {'%f:%l:%c: %trror: %m'; '%f:%l:%c: %tarning: %m'; '%f:%l:%c: %tote: %m'};
  }
end

local get_shfmt = function()
  return {['format-command'] = 'shfmt -'; ['format-stdin'] = true}
end

local get_luacheck = function()
  return {
    ['lint-command'] = 'luacheck --formatter plain --filename ${INPUT} -';
    ['lint-stdin'] = true;
    ['lint-formats'] = {'%f:%l:%c: %m'};
  }
end

local get_luaformat = function()
  return {['format-command'] = 'lua-format'; ['format-stdin'] = true}
end

local make_if_filename = function(languages)
  return function(fname, cb)
    if vfn.filereadable(fname) == 1 then
      cb(languages)
    end
  end
end

local make_if_executable = function(languages)
  return function(bin_name, cb)
    if vfn.executable(bin_name) == 1 then
      cb(languages)
    end
  end
end

local add_luaformat = function(languages)
  if languages.lua == nil then
    languages.lua = {}
  end
  table.insert(languages.lua, get_luaformat())
end

local add_luacheck = function(languages)
  if languages.lua == nil then
    languages.lua = {}
  end
  table.insert(languages.lua, get_luacheck())
end

local add_shellcheck = function(languages)
  if languages.sh == nil then
    languages.sh = {}
  end
  table.insert(languages.sh, get_shellcheck())
end

local add_shfmt = function(languages)
  if languages.sh == nil then
    languages.sh = {}
  end
  table.insert(languages.sh, get_shfmt())
end

local read_precommit_config = function(file_path)
  local lyaml = require('lyaml')
  local f = io.open(file_path, 'r')
  local content = f:read('all*')
  f:close()
  return lyaml.load(content)
end

local blackd_cleanup_if_needed = function(languages)
  if type(languages.python) == 'table' then
    for _, tool in pairs(languages.python) do
      if tool['format-command'] and vim.endswith(tool['format-command'], '/blackd-format') then
        require('lib.cleanup').register(function()
          local block = require('lib/cmd').run('pkill', {args = {'-f'; 'blackd'}}, nil, function()
          end)
          block(500)
        end)
      end
    end
  end
end

local add_python_language = function(languages)
  local pre_commit_config_file_path = '.pre-commit-config.yaml'
  if vfn.filereadable(pre_commit_config_file_path) == 0 then
    languages.python = {get_flake8(); get_dmypy(); get_black(); get_isort()}
    return
  end

  local pc_repo_map = {
    ['https://github.com/asottile/add-trailing-comma'] = get_add_trailing_comma;
    ['https://github.com/asottile/reorder_python_imports'] = get_reorder_python_imports;
    ['https://github.com/pre-commit/mirrors-autopep8'] = get_autopep8;
    ['https://github.com/pre-commit/mirrors-isort'] = get_isort;
    ['https://github.com/pre-commit/mirrors-mypy'] = get_dmypy;
    ['https://github.com/psf/black'] = get_black;
    ['https://gitlab.com/pycqa/flake8'] = get_flake8;
  }
  local pre_commit_config = read_precommit_config(pre_commit_config_file_path)
  local result = {}
  for _, repo in ipairs(pre_commit_config.repos) do
    local fn = pc_repo_map[repo.repo]
    if fn ~= nil then
      table.insert(result, fn())
    end
  end

  if not vim.tbl_isempty(result) then
    languages.python = result
  end
end

local get_config = function()
  local languages = {}

  add_python_language(languages)
  blackd_cleanup_if_needed(languages)
  local if_executable = make_if_executable(languages)
  local if_filename = make_if_filename(languages)

  if_filename('.luacheckrc', add_luacheck)
  if_filename('.lua-format', add_luaformat)

  if_executable('shellcheck', add_shellcheck)
  if_executable('shfmt', add_shfmt)
  if_executable('dune', function(langs)
    langs.dune = {get_dune()}
  end)

  local cfg = {
    version = 2;
    tools = {
      dmypy = get_dmypy();
      flake8 = get_flake8();
      add_trailing_comma = get_add_trailing_comma();
      reorder_python_imports = get_reorder_python_imports();
      autopep8 = get_autopep8();
      sort = get_isort();
      black = get_black();
      dune = get_dune();
      shellcheck = get_shellcheck();
      shfmt = get_shfmt();
      luaformat = get_luaformat();
      luacheck = get_luacheck();
    };
    languages = languages;
  }
  return require('lyaml').dump({cfg}), vim.tbl_keys(languages)
end

local cleanup = function()
  for _, file in pairs(created_files) do
    local ok, err = os.remove(file)
    if not ok then
      print(err)
    end
  end
  created_files = {}
end

function M.gen_config()
  local cache_dir = vfn.stdpath('cache')
  setup_blackd_logs_dir(cache_dir)

  local config_str, fts = get_config()
  local config_file = os.tmpname()
  local h = io.open(config_file, 'w')
  h:write(config_str)
  h:close()
  table.insert(created_files, config_file)
  return config_file, fts
end

do
  require('lib.cleanup').register(cleanup)
end

return M
