local has_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
local capabilities = has_cmp and cmp_nvim_lsp.default_capabilities() or nil

local servers = {
  "clangd",
  "lua_ls",
  "jsonls",
  "yamlls",
  "lemminx",
  "taplo",
  "bashls",
  "cmake",
}

local function clangd_before_init(params, config)
  local root = config.root_dir
    or (params.rootUri and vim.uri_to_fname(params.rootUri))
    or vim.uv.cwd()

  local candidates = {
    root .. "/build/compile_commands.json",
    root .. "/build/debug/compile_commands.json",
    root .. "/build/release/compile_commands.json",
    root .. "/build/clang/debug/compile_commands.json",
    root .. "/build/gcc/debug/compile_commands.json",
    root .. "/build/clang/release/compile_commands.json",
    root .. "/build/gcc/release/compile_commands.json",
  }

  local dir
  for _, path in ipairs(candidates) do
    if vim.uv.fs_stat(path) then
      dir = vim.fs.dirname(path)
      break
    end
  end

  local cmd = { "clangd", "--background-index=1" }
  if dir then
    table.insert(cmd, "--compile-commands-dir=" .. dir)
  end
  config.cmd = cmd
end

-- Neovim 0.11+: native vim.lsp.config / vim.lsp.enable
-- Keep Neovim's default LSP maps (K, grn, gra, grr, gri, grt, gO, [d, ]d).
if vim.lsp.config then
  vim.lsp.config("clangd", {
    capabilities = capabilities,
    before_init = clangd_before_init,
  })
  pcall(vim.lsp.enable, servers)
  return
end

-- Neovim 0.10 fallback via nvim-lspconfig
local ok_lspconfig, lspconfig = pcall(require, "lspconfig")
if not ok_lspconfig then
  return
end

for _, name in ipairs(servers) do
  local server = lspconfig[name]
  if server then
    local opts = { capabilities = capabilities }
    if name == "clangd" then
      opts.on_new_config = function(config, root_dir)
        clangd_before_init({ rootUri = vim.uri_from_fname(root_dir) }, config)
      end
    end
    pcall(server.setup, opts)
  end
end
