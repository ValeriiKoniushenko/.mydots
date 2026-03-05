vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.opt.showcmd = true
vim.opt.laststatus = 4
vim.opt.autowrite = true
vim.opt.cursorline = true
vim.opt.autoread = true
vim.opt.shell = "/bin/zsh"

-- use spaces for tabs and whatnot
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.shiftround = true
vim.opt.expandtab = true

vim.cmd [[ set noswapfile ]]
vim.cmd [[ set termguicolors ]]

-- vim.opt.clipboard = "unnamedplus"

--Line numbers
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"

vim.opt.completeopt = { "menu", "menuone", "noselect" }

-- Treesitter compatibility for plugins expecting ft_to_lang
do
  -- Newer Neovim: vim.treesitter.language.get_lang exists, old Telescope expects ft_to_lang
  local ok_lang, language = pcall(require, "vim.treesitter.language")
  if ok_lang and language and not language.ft_to_lang and language.get_lang then
    language.ft_to_lang = language.get_lang
  end

  -- Newer nvim-treesitter: parsers.filetype_to_parsername, old Telescope uses parsers.ft_to_lang
  local ok_parsers, parsers = pcall(require, "nvim-treesitter.parsers")
  if ok_parsers and parsers and not parsers.ft_to_lang then
    if parsers.filetype_to_parsername then
      parsers.ft_to_lang = parsers.filetype_to_parsername
    elseif language and language.get_lang then
      -- Fallback: delegate to vim.treesitter.language
      parsers.ft_to_lang = language.get_lang
    end
  end
end

