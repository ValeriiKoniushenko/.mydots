local has_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
local capabilities = has_cmp and cmp_nvim_lsp.default_capabilities() or nil

-- Buffer‑local LSP keymaps (Alt‑based, keep `gd` free)
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspKeymaps", { clear = true }),
  callback = function(ev)
    local opts = { buffer = ev.buf, silent = true }

    -- Navigation
    vim.keymap.set("n", "<A-d>", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "<A-D>", vim.lsp.buf.declaration, opts)
    vim.keymap.set("n", "<A-i>", vim.lsp.buf.implementation, opts)
    vim.keymap.set("n", "<A-r>", vim.lsp.buf.references, opts)

    -- Info / actions
    vim.keymap.set("n", "<A-k>", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<A-R>", vim.lsp.buf.rename, opts)
    vim.keymap.set({ "n", "v" }, "<A-a>", vim.lsp.buf.code_action, opts)
  end,
})

-- Custom clangd config: auto-pick compile_commands.json in build/*/*
vim.lsp.config("clangd", {
  capabilities = capabilities,
  before_init = function(params, config)
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
  end,
})

-- Enable specific LSP servers by name
vim.lsp.enable({
  "clangd",
  "lua_ls",
  "jsonls",
  "yamlls",
  "lemminx",
  "taplo",
  "bashls",
  "cmake",
})

