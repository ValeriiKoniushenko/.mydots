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

require("dap").adapters.codelldb = {
    type = "server",
    port = "${port}",
    executable = {
        command = "codelldb",
        args = { "--port", "${port}" },
    },
}
