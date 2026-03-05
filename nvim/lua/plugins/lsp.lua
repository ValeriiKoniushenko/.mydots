local util = require('lspconfig.util')

vim.lsp.config('clangd', {
  filetypes = { "c", "cpp", "objc", "objcpp" },
  root_dir = util.root_pattern("CMakeLists.txt", "compile_commands.json", ".git"),
  cmd = { "clangd", "--background-index=1", "--compile-commands-dir=" .. vim.fn.getcwd() }, -- Explicitly set the directory
})

vim.lsp.config('lua_ls', {
  on_init = function(client)
    if client.workspace_folders then
      local path = client.workspace_folders[1].name
      if path ~= vim.fn.stdpath('config') and (vim.uv.fs_stat(path..'/.luarc.json') or vim.uv.fs_stat(path..'/.luarc.jsonc')) then
        return
      end
    end

    client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
      runtime = {
        version = 'LuaJIT'
      },
      workspace = {
        checkThirdParty = false,
        library = {
          vim.env.VIMRUNTIME
        }
      }
    })
  end,
  settings = {
    Lua = {}
  }
})

