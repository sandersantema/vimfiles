local M = {}

local api = vim.api

local attached = function(bufnr, client)
  local helpers = require('lib.nvim_helpers')
  vim.schedule(function()
    local mappings = {
      n = {
        {
          lhs = '<localleader>dl';
          rhs = helpers.cmd_map([[lua require('lc.diagnostics').show_line_diagnostics()]]);
          opts = {silent = true};
        };
        {
          lhs = '<localleader>df';
          rhs = helpers.cmd_map([[lua require('lc.diagnostics').list_file_diagnostics()]]);
          opts = {silent = true};
        };
        {
          lhs = '<localleader>dw';
          rhs = helpers.cmd_map([[lua require('lc.diagnostics').list_workspace_diagnostics()]]);
          opts = {silent = true};
        };
        {
          lhs = '<localleader>cl';
          rhs = helpers.cmd_map([[lua require('lc.buf_diagnostic').buf_clear_diagnostics()]]);
          opts = {silent = true};
        };
      };
      i = {};
    }

    if client.resolved_capabilities.completion ~= nil and client.resolved_capabilities.completion ~=
      false then
      vim.cmd('packadd completion-nvim')
      require('completion').on_attach({
        trigger_on_delete = 1;
        auto_change_source = 1;
        confirm_key = [[\<C-y>]];
        matching_strategy_list = {'exact'; 'fuzzy'};
        chain_complete_list = {
          default = {
            {complete_items = {'lsp'}};
            {complete_items = {'buffers'}};
            {mode = {'<c-p>'}};
            {mode = {'<c-n>'}};
          };
        };
      })
      table.insert(mappings.i, {
        lhs = '<c-x><c-o>';
        rhs = 'v:lua.f.complete()';
        opts = {expr = true; silent = true};
      })
      table.insert(mappings.i,
                   {lhs = '<cr>'; rhs = 'v:lua.f.cr()'; opts = {expr = true; noremap = true}})
    end

    if client.resolved_capabilities.rename ~= nil and client.resolved_capabilities.rename ~= false then
      table.insert(mappings.n, {
        lhs = '<localleader>r';
        rhs = helpers.cmd_map('lua vim.lsp.buf.rename()');
        opts = {silent = true};
      })
    end

    if client.resolved_capabilities.code_action then
      table.insert(mappings.n, {
        lhs = '<localleader>cc';
        rhs = helpers.cmd_map('lua vim.lsp.buf.code_action()');
        opts = {silent = true};
      })
    end

    if client.resolved_capabilities.declaration then
      table.insert(mappings.n, {
        lhs = '<localleader>gy';
        rhs = helpers.cmd_map('lua vim.lsp.buf.declaration()');
        opts = {silent = true};
      })
      table.insert(mappings.n, {
        lhs = '<localleader>py';
        rhs = helpers.cmd_map([[lua require('lc.locations').preview_declaration()]]);
        opts = {silent = true};
      })
    end

    if client.resolved_capabilities.document_formatting then
      require('lc.formatting').register_client(client, bufnr)
    end

    table.insert(mappings.n, {
      lhs = '<localleader>s';
      rhs = helpers.cmd_map('lua vim.lsp.buf.document_highlight()');
      opts = {silent = true};
    })
    table.insert(mappings.n, {
      lhs = '<localleader>S';
      rhs = helpers.cmd_map('lua vim.lsp.buf.clear_references()');
      opts = {silent = true};
    })

    if client.resolved_capabilities.document_symbol then
      vim.g.vista_default_executive = 'nvim_lsp'
      table.insert(mappings.n, {
        lhs = '<localleader>t';
        rhs = helpers.cmd_map('lua vim.lsp.buf.document_symbol()');
        opts = {silent = true};
      })
      table.insert(mappings.n, {
        lhs = '<localleader>v';
        rhs = helpers.cmd_map('Vista!!');
        opts = {silent = true};
      })
    end

    if client.resolved_capabilities.find_references then
      table.insert(mappings.n, {
        lhs = '<localleader>q';
        rhs = helpers.cmd_map('lua vim.lsp.buf.references()');
        opts = {silent = true};
      })
    end

    if client.resolved_capabilities.goto_definition then
      table.insert(mappings.n, {
        lhs = '<localleader>gd';
        rhs = helpers.cmd_map('lua vim.lsp.buf.definition()');
        opts = {silent = true};
      })
      table.insert(mappings.n, {
        lhs = '<localleader>pd';
        rhs = helpers.cmd_map([[lua require('lc.locations').preview_definition()]]);
        opts = {silent = true};
      })
    end

    if client.resolved_capabilities.hover then
      table.insert(mappings.n, {
        lhs = '<localleader>i';
        rhs = helpers.cmd_map('lua vim.lsp.buf.hover()');
        opts = {silent = true};
      })
    end

    if client.resolved_capabilities.implementation then
      table.insert(mappings.n, {
        lhs = '<localleader>gi';
        rhs = helpers.cmd_map('lua vim.lsp.buf.implementation()');
        opts = {silent = true};
      })
      table.insert(mappings.n, {
        lhs = '<localleader>pi';
        rhs = helpers.cmd_map([[lua require('lc.locations').preview_implementation()]]);
        opts = {silent = true};
      })
    end

    if client.resolved_capabilities.signature_help then
      table.insert(mappings.n, {
        lhs = '<c-k>';
        rhs = helpers.cmd_map('lua vim.lsp.buf.signature_help()');
        opts = {silent = true};
      })
      table.insert(mappings.i, {
        lhs = '<c-k>';
        rhs = helpers.cmd_map('lua vim.lsp.buf.signature_help()');
        opts = {silent = true};
      })
    end

    if client.resolved_capabilities.type_definition then
      table.insert(mappings.n, {
        lhs = '<localleader>gt';
        rhs = helpers.cmd_map('lua vim.lsp.buf.type_definition()');
        opts = {silent = true};
      })
      table.insert(mappings.n, {
        lhs = '<localleader>pt';
        rhs = helpers.cmd_map([[lua require('lc.locations').preview_type_definition()]]);
        opts = {silent = true};
      })
    end

    if client.resolved_capabilities.workspace_symbol then
      table.insert(mappings.n, {
        lhs = '<localleader>T';
        rhs = helpers.cmd_map('lua vim.lsp.buf.workspace_symbol()');
        opts = {silent = true};
      })
    end

    vim.schedule(function()
      helpers.create_mappings(mappings, bufnr)
    end)
  end)
end

local on_attach = function(client, bufnr)
  local all_clients = vim.lsp.get_active_clients()
  for _, c in pairs(all_clients) do
    if c.id == client.id then
      client = c
    end
  end

  if bufnr == 0 or bufnr == nil then
    bufnr = api.nvim_get_current_buf()
  end

  attached(bufnr, client)
end

function M.with_default_opts(opts)
  return vim.tbl_extend('keep', opts, {
    callbacks = require('lc.callbacks');
    on_attach = on_attach;
    capabilities = vim.tbl_deep_extend('keep', opts.capabilities or {}, {
      textDocument = {completion = {completionItem = {snippetSupport = false}}};
    }, require('vim.lsp.protocol').make_client_capabilities());
  });
end

M.project_root_pattern = function()
  return require('nvim_lsp').util.root_pattern('.git')
end

M.cwd_root_pattern = function()
  return vim.fn.getcwd()
end

return M
