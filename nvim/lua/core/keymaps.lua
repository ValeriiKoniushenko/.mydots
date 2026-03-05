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

-- Switch between C++ source and header with Alt+O
Map("n", "<A-o>", function()
  local ts = vim.fn.expand("%:t")
  local root = vim.fn.expand("%:r")
  local ext = vim.fn.expand("%:e")

  local candidates = {}
  if ext == "cpp" or ext == "cc" or ext == "cxx" or ext == "c" then
    candidates = { root .. ".h", root .. ".hpp", root .. ".hh" }
  elseif ext == "h" or ext == "hpp" or ext == "hh" then
    candidates = { root .. ".cpp", root .. ".cc", root .. ".cxx", root .. ".c" }
  end

  for _, file in ipairs(candidates) do
    if vim.loop.fs_stat(file) then
      vim.cmd.edit(file)
      return
    end
  end
end)

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
Map('n', '<C-f>f', ":Telescope find_files hidden=true<CR>")
Map('n', '<C-A-f>', ":lua require('telescope.builtin').live_grep({additional_args = {'--hidden'}})<CR>")
Map('n', '<C-A-t>', ":Telescope find_files hidden=true<CR>")

-- Toggleterm
Map('n', '<C-`>', ":ToggleTerm<CR>")
Map('i', '<C-`>', ":ToggleTerm<CR>")

-- DAP (debugging)
Map("n", "<F5>", function() require("dap").continue() end)
Map("n", "<F10>", function() require("dap").step_over() end)
Map("n", "<F11>", function() require("dap").step_into() end)
Map("n", "<F12>", function() require("dap").step_out() end)
Map("n", "<leader>b", function() require("dap").toggle_breakpoint() end)
Map("n", "<leader>B", function()
  require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
end)
Map("n", "<leader>dr", function() require("dap").repl.open() end)
Map("n", "<leader>du", function() require("dapui").toggle() end)
