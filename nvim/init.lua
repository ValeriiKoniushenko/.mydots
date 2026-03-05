-- Basics
require("core.options")
require("core.plugins")
require("core.keymaps")

-- Plugins
require("plugins.neotree")
-- require("plugins.treesitter")
require("plugins.lsp")
require("plugins.gruvbox")
require("plugins.cmp")
require("plugins.mason")
require("plugins.telescope")
-- require("plugins.autosession")
require("plugins.dap")

require("dap").adapters.codelldb = {
  type = "server",
  port = "${port}",
  executable = {
    -- make sure `codelldb` is in PATH, or set absolute path here
    command = "codelldb",
    args = { "--port", "${port}" },
  },
}
