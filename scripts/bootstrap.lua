local vfn = vim.fn
local cmd = require('lib.cmd')

local second_ms = 1000
local minute_ms = 60 * second_ms

local config_dir = vfn.stdpath('config')
local cache_dir = vfn.stdpath('cache')
local site_dir = string.format('%s/site', vfn.stdpath('data'))

local pip_packages = {'pip'; 'pip-tools'; 'git+https://github.com/luarocks/hererocks.git'}

local rocks = {'lyaml'; 'luacheck'; 'environ'; 'busted'}

local debug = function(msg)
  if os.getenv('NVIM_DEBUG') then
    print('[DEBUG] ' .. msg)
  end
end

local cmd_to_string = function(cmd_name, args)
  local quoted_args = {}
  for i, arg in ipairs(args or {}) do
    quoted_args[i] = string.format('"%s"', arg)
  end
  return string.format('%s %s', cmd_name, table.concat(quoted_args, ' '))
end

local cmd_status = function(result)
  if type(result) ~= 'table' then
    return 'aborted'
  end

  if result.exit_status == 0 then
    return 'success'
  end

  return string.format('exit status %d - %s', result.exit_status, result.stderr)
end

-- run the given commands and block until all of them are done. it raises an
-- error if any of the command fails, with information about the failure (exit
-- status + stderr).
--
-- The input is a table of commands, where each command is a table in the following format:
--
-- {
--    executable: string;
--    opts: table; (note: this should match vim.loop.spawn options, see lib/cmd.lua for details)
--    timeout_ms: number; (defaults to 20 minutes)
-- }
local run_cmds = function(cmds)
  local twenty_minutes_ms = 20 * minute_ms
  local results = {}
  local total_timeout_ms = 0

  for _, c in pairs(cmds) do
    local timeout_ms = c.timeout_ms or twenty_minutes_ms
    if timeout_ms > total_timeout_ms then
      total_timeout_ms = timeout_ms
    end

    local cmd_str = cmd_to_string(c.executable, c.opts.args)
    results[cmd_str] = 0
    debug(string.format('running "%s"', cmd_str))
    cmd.run(c.executable, c.opts, nil, function(result)
      results[cmd_str] = result
    end, debug)
  end

  local status = vim.wait(total_timeout_ms, function()
    for _, r in pairs(results) do
      if r == 0 then
        return false
      end
    end
    return true
  end, 500)

  if not status then
    local statuses = {}
    for cmd_str, result in pairs(results) do
      table.insert(statuses, string.format('%s: %s', cmd_str, cmd_status(result)))
    end
    error(string.format('failed to complete all commands in %dms\nStatus:\n', total_timeout_ms,
                        table.concat(statuses, '\n')))
  end

  for cmd_str, result in pairs(results) do
    if result.exit_status ~= 0 then
      error(string.format('command "%s" failed: %s', cmd_str, cmd_status(result)))
    end
  end
end

local download_virtualenv_pyz = function()
  local file_name = cache_dir .. '/virtualenv.pyz'
  if vfn.filereadable(file_name) == 0 then
    run_cmds({
      {
        executable = 'curl';
        opts = {args = {'-sLo'; file_name; 'https://bootstrap.pypa.io/virtualenv.pyz'}};
      };
    })
  end
  return file_name
end

local ensure_virtualenv = function()
  local venv_dir = cache_dir .. '/venv'
  if vfn.isdirectory(venv_dir) == 0 then
    local venv_pyz = download_virtualenv_pyz()
    run_cmds({
      {
        executable = 'python3';
        opts = {args = {venv_pyz; '-p'; 'python3'; venv_dir}};
        timeout_ms = 5 * minute_ms;
      };
    })
  end
  run_cmds({
    {
      executable = cache_dir .. '/venv/bin/pip';
      opts = {
        args = vim.tbl_flatten({
          {'install'; '--upgrade'};
          pip_packages;
          {'-r'; config_dir .. '/langservers/requirements.txt'};
        });
      };
    };
  })
  return venv_dir
end

local ensure_hererocks = function(virtualenv)
  local hr_dir = cache_dir .. '/hr'
  if vfn.isdirectory(hr_dir) == 0 then
    run_cmds({
      {
        executable = virtualenv .. '/bin/hererocks';
        opts = {args = {'-j'; 'latest'; '-r'; 'latest'; hr_dir}};
      };
    })
  end

  for _, rock in pairs(rocks) do
    run_cmds({
      {executable = hr_dir .. '/bin/luarocks'; opts = {args = vim.tbl_flatten({'install'; rock})}};
    })
  end

  return hr_dir
end

local setup_langservers = function()
  run_cmds({
    {
      executable = config_dir .. '/langservers/setup.sh';
      opts = {args = {cache_dir .. '/langservers'}};
    };
  })
end

local install_autoload_plugins = function()
  vfn.mkdir(site_dir .. '/autoload', 'p')
  run_cmds({
    {
      executable = 'curl';
      opts = {
        args = {
          '-sLo';
          site_dir .. '/autoload/fzf.vim';
          'https://raw.githubusercontent.com/junegunn/fzf/HEAD/plugin/fzf.vim';
        };
      };
    };
  })
end

local ensure_packer_nvim = function()
  local packer_dir = string.format('%s/pack/packer/opt/packer.nvim', site_dir)
  vfn.mkdir(packer_dir, 'p')
  if vfn.isdirectory(packer_dir .. '/.git') == 0 then
    run_cmds({
      {
        executable = 'git';
        opts = {
          args = {'clone'; '--depth=1'; 'https://github.com/wbthomason/packer.nvim'; packer_dir};
        };
      };
    })
  end

  vim.o.packpath = string.format('%s,%s', site_dir, vim.o.packpath)
  require('packed').setup()
  require('packer').sync()
end

do
  local autoload_done = false
  local packer_done = false
  local hererocks_done = false
  vim.schedule(function()
    install_autoload_plugins()
    autoload_done = true
  end)
  vim.schedule(function()
    ensure_packer_nvim()
    packer_done = true
  end)
  vfn.mkdir(cache_dir, 'p')
  local virtualenv = ensure_virtualenv()
  debug(string.format('created virtualenv at "%s"\n', virtualenv))
  vim.schedule(function()
    local hr_dir = ensure_hererocks(virtualenv)
    debug(string.format('created hererocks at "%s"\n', hr_dir))
    hererocks_done = true
  end)
  setup_langservers()
  vim.wait(20 * minute_ms, function()
    return autoload_done and hererocks_done and packer_done
  end, 25)
end
