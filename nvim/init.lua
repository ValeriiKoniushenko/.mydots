require("core.options")
require("core.plugins")
require("core.keymaps")

-- Plugins
require("plugins.neotree")
require("plugins.treesitter")
require("plugins.lsp")
require("plugins.gruvbox")
require("plugins.cmp")
require("plugins.mason")
require("plugins.telescope")
require("plugins.llama_server") -- auto-start llama-server for local FIM (Minuet)
-- require("plugins.autosession")
require("plugins.dap")

require("dap").adapters.codelldb = {
  type = "server",
  port = "${port}",
  executable = {
    -- Prefer Mason-installed codelldb
    command = vim.fn.stdpath("data") .. "/mason/bin/codelldb",
    args = { "--port", "${port}" },
  },
}
