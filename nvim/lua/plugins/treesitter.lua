local parsers = {
  -- Core / Neovim
  "lua",
  "vim",
  "vimdoc",
  "markdown",
  "markdown_inline",

  -- C / C++ and friends
  "c",
  "cpp",
  "cmake",

  -- Git / tooling
  "git_config",
  "git_rebase",
  "gitattributes",
  "gitcommit",
  "gitignore",

  -- Linux / config files
  "bash",
  "ini",
  "ssh_config",
  "yaml",
  "json",
  "toml",
  "dockerfile",

  -- Markup / data
  "html",
  "xml",

  -- Utilities
  "comment",
  "regex",
}

-- Master-branch API (nvim-treesitter.configs)
local ok_configs, configs = pcall(require, "nvim-treesitter.configs")
if ok_configs and configs.setup then
  configs.setup({
    ensure_installed = parsers,
    sync_install = false,
    auto_install = true,
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false,
    },
  })
  return
end

-- Main-branch API (Neovim 0.12+)
local ok_ts, nvim_ts = pcall(require, "nvim-treesitter")
if not ok_ts then
  return
end

-- Compiling parsers needs the tree-sitter CLI; skip install if it is missing.
if vim.fn.executable("tree-sitter") == 1 then
  pcall(nvim_ts.install, parsers)
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("UserTreesitterHighlight", { clear = true }),
  callback = function(ev)
    pcall(vim.treesitter.start, ev.buf)
  end,
})
