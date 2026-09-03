local function Map(mode, lhs, rhs, opts)
  local options = { noremap = true, silent = true }
  if opts then
    options = vim.tbl_extend("force", options, opts)
  end
  vim.keymap.set(mode, lhs, rhs, options)
end

local function plugin_cmd(command, missing)
  return function()
    local name = command:match("^(%S+)")
    if vim.fn.exists(":" .. name) ~= 2 then
      vim.notify(missing or (name .. " is not installed"), vim.log.levels.WARN)
      return
    end
    vim.cmd(command)
  end
end

local function with_module(mod, fn, missing)
  return function(...)
    local ok, m = pcall(require, mod)
    if not ok then
      vim.notify(missing or (mod .. " is not installed"), vim.log.levels.WARN)
      return
    end
    return fn(m, ...)
  end
end

-- Save (popular). Default window splits stay as :vsplit / <C-w>v
Map("n", "<C-s>", "<Cmd>write<CR>")
Map("i", "<C-s>", "<Cmd>write<CR>")
Map("v", "<C-s>", "<Cmd>write<CR>")

-- Resize splits with arrows (does not steal default letter keys)
Map("n", "<C-Up>", "<Cmd>resize +2<CR>")
Map("n", "<C-Down>", "<Cmd>resize -2<CR>")
Map("n", "<C-Left>", "<Cmd>vertical resize +2<CR>")
Map("n", "<C-Right>", "<Cmd>vertical resize -2<CR>")

-- Move lines (popular VS Code-style; Alt is unused by Neovim defaults)
Map("n", "<A-j>", ":m .+1<CR>==")
Map("n", "<A-k>", ":m .-2<CR>==")
Map("v", "<A-j>", ":m '>+1<CR>gv=gv")
Map("v", "<A-k>", ":m '<-2<CR>gv=gv")

-- Stay in visual mode while indenting
Map("v", "<", "<gv")
Map("v", ">", ">gv")

-- Switch between C/C++ source and header
Map("n", "<A-o>", function()
  local root = vim.fn.expand("%:r")
  local ext = vim.fn.expand("%:e")

  local candidates = {}
  if ext == "cpp" or ext == "cc" or ext == "cxx" or ext == "c" then
    candidates = { root .. ".h", root .. ".hpp", root .. ".hh" }
  elseif ext == "h" or ext == "hpp" or ext == "hh" then
    candidates = { root .. ".cpp", root .. ".cc", root .. ".cxx", root .. ".c" }
  else
    return
  end

  for _, file in ipairs(candidates) do
    if vim.uv.fs_stat(file) then
      vim.cmd.edit(file)
      return
    end
  end
end)

-- ===== PLUGINS ===== --
-- File explorer (popular <leader>e; keeps default <C-e> scroll)
Map("n", "<leader>e", plugin_cmd("Neotree toggle", "neo-tree is not installed"))

-- Diagnostics list (popular; Neovim still has [d / ]d / <C-w>d)
Map("n", "<leader>q", function()
  vim.diagnostic.setloclist({ open = false })
  local window = vim.api.nvim_get_current_win()
  vim.cmd.lwindow()
  vim.api.nvim_set_current_win(window)
end)

-- Telescope (popular defaults)
Map("n", "<leader>ff", with_module("telescope.builtin", function(builtin)
  builtin.find_files({ hidden = true })
end, "telescope.nvim is not installed"))
Map("n", "<leader>fg", with_module("telescope.builtin", function(builtin)
  builtin.live_grep({ additional_args = { "--hidden" } })
end, "telescope.nvim is not installed"))

-- ToggleTerm (popular VS Code-style terminal toggle)
Map("n", "<C-`>", plugin_cmd("ToggleTerm", "toggleterm.nvim is not installed"))
Map("i", "<C-`>", plugin_cmd("ToggleTerm", "toggleterm.nvim is not installed"))
Map("t", "<C-`>", plugin_cmd("ToggleTerm", "toggleterm.nvim is not installed"))

-- Gemini CLI in a terminal (no-op with a warning if ToggleTerm is missing)
Map("n", "<leader>gg", plugin_cmd("TermExec cmd='gemini'", "toggleterm.nvim is not installed"))

-- DAP (F-keys match VS Code / common IDE bindings)
Map("n", "<F5>", with_module("dap", function(dap) dap.continue() end, "nvim-dap is not installed"))
Map("n", "<F9>", with_module("dap", function(dap) dap.toggle_breakpoint() end, "nvim-dap is not installed"))
Map("n", "<F10>", with_module("dap", function(dap) dap.step_over() end, "nvim-dap is not installed"))
Map("n", "<F11>", with_module("dap", function(dap) dap.step_into() end, "nvim-dap is not installed"))
Map("n", "<F12>", with_module("dap", function(dap) dap.step_out() end, "nvim-dap is not installed"))
Map("n", "<leader>b", with_module("dap", function(dap) dap.toggle_breakpoint() end, "nvim-dap is not installed"))
Map("n", "<leader>B", with_module("dap", function(dap)
  dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
end, "nvim-dap is not installed"))
Map("n", "<leader>dr", with_module("dap", function(dap) dap.repl.open() end, "nvim-dap is not installed"))
Map("n", "<leader>du", with_module("dapui", function(dapui) dapui.toggle() end, "nvim-dap-ui is not installed"))
