local ok, configs = pcall(require, "nvim-treesitter.configs")
if not ok then
  return
end

configs.setup({
  ensure_installed = {
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
    "jsonc",
    "toml",
    "dockerfile",

    -- Markup / data
    "html",
    "xml",

    -- Utilities
    "comment",
    "regex",
  },

  sync_install = false,
  auto_install = true,

  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
})
