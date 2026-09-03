
local function safe_require(mod)
  local ok, err = pcall(require, mod)
  if not ok then
    vim.notify("Skipped " .. mod .. " (" .. tostring(err) .. ")", vim.log.levels.WARN)
  end
  return ok
end

require("core.options")
require("core.clipboard")
safe_require("core.plugins")
require("core.keymaps")

-- Plugin setups (each file also guards its own require)
safe_require("plugins.neotree")
safe_require("plugins.treesitter")
safe_require("plugins.lsp")
safe_require("plugins.gruvbox")
safe_require("plugins.cmp")
safe_require("plugins.mason")
safe_require("plugins.telescope")
safe_require("plugins.luasnip")
safe_require("plugins.autosession")
safe_require("plugins.dap")

-- DAP adapter: only if nvim-dap is present and codelldb exists
local dap_ok, dap = pcall(require, "dap")
if dap_ok then
  local mason_codelldb = vim.fn.stdpath("data") .. "/mason/bin/codelldb"
  local command = (vim.fn.executable(mason_codelldb) == 1 and mason_codelldb)
    or (vim.fn.executable("codelldb") == 1 and "codelldb")
    or nil

  if command then
    dap.adapters.codelldb = {
      type = "server",
      port = "${port}",
      executable = {
        command = command,
        args = { "--port", "${port}" },
      },
    }
  end
end
