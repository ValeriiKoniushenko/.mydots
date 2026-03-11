require("mason").setup({
  ui = {
    icons = {
      package_installed = "✓",
      package_pending = "➜",
      package_uninstalled = "✗",
    },
  },
})

local ok_mason_lspconfig, mason_lspconfig = pcall(require, "mason-lspconfig")
if ok_mason_lspconfig then
  mason_lspconfig.setup({
    ensure_installed = {
      -- Existing
      "clangd",
      "lua_ls",

      -- Linux / config & scripting
      "bashls",   -- Bash / shell scripts
      "jsonls",   -- JSON / JSONC
      "yamlls",   -- YAML
      "lemminx",  -- XML
      "taplo",    -- TOML
      -- "cmake",    -- CMake
    },
    automatic_installation = true,
  })
end
