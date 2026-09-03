local ok, mason = pcall(require, "mason")
if not ok then
  return
end

mason.setup({
  ui = {
    icons = {
      package_installed = "✓",
      package_pending = "➜",
      package_uninstalled = "✗",
    },
  },
})

local ok_mason_lspconfig, mason_lspconfig = pcall(require, "mason-lspconfig")
if not ok_mason_lspconfig then
  return
end

mason_lspconfig.setup({
  ensure_installed = {
    "clangd",
    "lua_ls",
    "bashls",
    "jsonls",
    "yamlls",
    "lemminx",
    "taplo",
  },
})
