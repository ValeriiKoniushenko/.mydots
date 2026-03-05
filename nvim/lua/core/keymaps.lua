function Map(mode, lhs, rhs, opts)
    local options = { noremap = true, silent = true }
    if opts then
        options = vim.tbl_extend("force", options, opts)
    end
    vim.keymap.set(mode, lhs, rhs, options)
end

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"


-- Better window navigation
Map("n", "<C-h>", "<C-w>h")
Map("n", "<C-j>", "<C-w>j")
Map("n", "<C-k>", "<C-w>k")
Map("n", "<C-l>", "<C-w>l")

-- Splitting
Map("n", "<C-s>", ":vsplit<CR>")
-- Map("n", "<C-s>h", ":split<CR>")
-- Map("n", "<C-s>d", ":close<CR>")

-- Resize with arrows
Map("n", "<C-Up>", ":resize +2<CR>")
Map("n", "<C-Down>", ":resize -2<CR>")
Map("n", "<C-Left>", ":vertical resize +2<CR>")
Map("n", "<C-Right>", ":vertical resize -2<CR>")

-- Move text up and down
Map("n", "<A-j>", ":m .+1<CR>==")
Map("n", "<A-k>", ":m .-2<CR>==")
Map("v", "<A-j>", ":m '>+1<CR>gv=gv")
Map("v", "<A-k>", ":m '<-2<CR>gv=gv")

-- Indenting
Map("n", "<Tab", ">>")
Map("n", "<s-Tab>", "<<")
Map("v", "<Tab>", ">gv")
Map("v", "<s-Tab>", "<gv")

-- Tabs
Map("n", "gc", ":tabclose<CR>")

-- ===== PLUGINS =====  --
-- NeoTree
Map("n", "<C-e>", "<Cmd>Neotree toggle<CR>")

-- Vim diagnostic
vim.keymap.set("n", "<C-q>", function()
  vim.diagnostic.setloclist({ open = false }) -- don't open and focus
  local window = vim.api.nvim_get_current_win()
  vim.cmd.lwindow() -- open+focus loclist if has entries, else close -- this is the magic toggle command
  vim.api.nvim_set_current_win(window) -- restore focus to window you were editing (delete this if you want to stay in loclist)
end, { buffer = bufnr })

-- Telescope
Map('n', '<C-f>g', ":lua require('telescope.builtin').live_grep({additional_args = {'--hidden'}})<CR>")
Map('n', '<C-f>f', ":Telescope find_files hidden=true no_ignore=true<CR>")
Map('n', '<C-A-f>', ":lua require('telescope.builtin').live_grep({additional_args = {'--hidden'}})<CR>")

-- Toggleterm
Map('n', '<C-`>', ":ToggleTerm<CR>")
Map('i', '<C-`>', ":ToggleTerm<CR>")
