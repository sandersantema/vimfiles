local vfn = vim.fn
local loop = vim.loop
local lc_opts = require('lc.opts')

local config_dir = vfn.stdpath('config')

local get_local_cmd = function(cmd)
  return string.format('%s/langservers/bin/%s', config_dir, cmd)
end

local set_log_level = function()
  local level = 'ERROR'
  if loop.os_getenv('NVIM_DEBUG') then
    level = 'TRACE'
  end
  require('vim.lsp.log').set_level(level)
end

local python_interpreter_props = function(virtual_env)
  local props = {InterpreterPath = virtual_env .. '/bin/python'; UseDefaultDatabase = true}
  local cb = function(r)
    if r.exit_status ~= 0 then
      print(string.format('failed to detect python version in the virtualenv $%s: %s', virtual_env,
                          r.stderr))
      return
    end
    props.Version = r.stdout
  end
  print(props.InterpreterPath)
  require('lib.cmd').run(props.InterpreterPath, {
    args = {
      '-c'; [[import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}", end="")]];
    };
  }, nil, cb)
  vim.wait(200, function()
    return props.Version ~= nil
  end, 25)
  return props
end

local get_pyls_ms_options = function()
  local opts = {cmd = {get_local_cmd('ms-python-lsp')}; root_dir = lc_opts.project_root_pattern}
  local virtual_env = loop.os_getenv('VIRTUAL_ENV')
  if virtual_env then
    local props = python_interpreter_props(virtual_env)
    if props.Version then
      opts.init_options = {interpreter = {properties = props}}
    end
  end
  return opts
end

do
  local if_executable = function(name, cb)
    if vfn.executable(name) == 1 then
      cb()
    end
  end

  set_log_level()
  local lsp = require('nvim_lsp')
  local vim_node_ls = get_local_cmd('node-lsp')

  if_executable('npx', function()
    lsp.bashls.setup(lc_opts.with_default_opts({
      cmd = {vim_node_ls; 'bash-language-server'; 'start'};
    }))

    lsp.cssls.setup(
      lc_opts.with_default_opts({cmd = {vim_node_ls; 'css-laguageserver'; '--stdio'}}))

    lsp.html.setup(lc_opts.with_default_opts({cmd = {vim_node_ls; 'html-langserver'; '--stdio'}}))

    lsp.jsonls.setup(lc_opts.with_default_opts({
      cmd = {vim_node_ls; 'vscode-json-languageserver'; '--stdio'};
    }))

    lsp.tsserver.setup(lc_opts.with_default_opts({
      cmd = {vim_node_ls; 'typescript-language-server'; '--stdio'};
      filetypes = {'javascript'; 'typescript'; 'typescriptreact'; 'typescript.tsx'};
    }))

    lsp.vimls.setup(lc_opts.with_default_opts({
      cmd = {vim_node_ls; 'vim-language-server'; '--stdio'};
    }))

    lsp.yamlls.setup(lc_opts.with_default_opts({
      cmd = {vim_node_ls; 'yaml-language-server'; '--stdio'};
    }))
  end)

  if_executable(get_local_cmd('gopls'), function()
    lsp.gopls.setup(lc_opts.with_default_opts({
      cmd = {get_local_cmd('go-lsp')};
      init_options = {
        deepCompletion = false;
        staticcheck = true;
        analyses = {unusedparams = true; ST1000 = false};
      };
    }))
  end)

  if_executable('dune', function()
    lsp.ocamllsp.setup(lc_opts.with_default_opts({cmd = {get_local_cmd('ocaml-lsp')}}))
  end)

  if_executable('dotnet', function()
    lsp.pyls_ms.setup(lc_opts.with_default_opts(get_pyls_ms_options()))
  end)

  local ra = get_local_cmd('rust-analyzer')
  if_executable('ra', function()
    lsp.rust_analyzer.setup(lc_opts.with_default_opts({cmd = {ra}}))
  end)

  local efm = get_local_cmd('efm-langserver')
  if_executable(efm, function()
    local config_file, filetypes = require('lc.efm').gen_config()
    lsp.efm.setup(lc_opts.with_default_opts({
      cmd = {efm; '-c'; config_file};
      filetypes = filetypes;
      root_dir = lc_opts.cwd_root_pattern;
    }))
  end)

  if_executable('ninja', function()
    lsp.sumneko_lua.setup(lc_opts.with_default_opts(
                            {
        cmd = {get_local_cmd('lua-lsp')};
        settings = {
          Lua = {
            runtime = {version = 'LuaJIT'};
            diagnostics = {
              enable = true;
              globals = {
                'vim'; 'describe'; 'it'; 'before_each'; 'after_each'; 'teardown'; 'pending';
              };
            };
          };
        };
      }))
  end)

  local clangd = loop.os_getenv('HOMEBREW_PREFIX') .. '/opt/llvm/bin/clangd'
  if_executable(clangd, function()
    lsp.clangd.setup(lc_opts.with_default_opts({
      cmd = {clangd; '--background-index'; '--pch-storage=memory'};
    }))
  end)
end
