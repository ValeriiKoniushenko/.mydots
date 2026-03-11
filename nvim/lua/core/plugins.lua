local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons",
			"MunifTanjim/nui.nvim",
			"3rd/image.nvim",
		}
	},
	{ 
        'nvim-treesitter/nvim-treesitter'
    },
    {
        "neovim/nvim-lspconfig",
    },
    { 
        "ellisonleao/gruvbox.nvim"
    },
    {
        'hrsh7th/nvim-cmp'
    },
    {
        'hrsh7th/cmp-buffer'
    },
    {
        'hrsh7th/cmp-path'
    },
    {
        'hrsh7th/cmp-nvim-lua'
    },
    {
        'hrsh7th/cmp-nvim-lsp'
    },
    {
        'saadparwaiz1/cmp_luasnip'
    },
    {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
    },
    {
        'nvim-telescope/telescope.nvim',
        -- use latest compatible version instead of old 0.1.8 tag
        dependencies = { 'nvim-lua/plenary.nvim' }
    },
    {
        "BurntSushi/ripgrep"
    },
    {
        'rmagatti/auto-session',
        lazy = false,
        opts = {
            suppressed_dirs = { '~/', '~/Downloads', '/' },
        }
    },
    {
        'akinsho/toggleterm.nvim',
        version = "*",
        config = true
    },
    {
        "mfussenegger/nvim-dap"
    },
    {
        "rcarriga/nvim-dap-ui",
        dependencies = {
            "mfussenegger/nvim-dap", 
            "nvim-neotest/nvim-nio"
        } 
    },
    {
        "L3MON4D3/LuaSnip",
        version = "v2.*",
        build = "make install_jsregexp",
        dependencies = {
            "rafamadriz/friendly-snippets",
        },
    },
    {
        "milanglacier/minuet-ai.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
        },
        opts = {
            provider = "openai_fim_compatible",
            n_completions = 1,
            context_window = 8192,
            throttle = 300,
            debounce = 200,
            provider_options = {
                openai_fim_compatible = {
                    -- Using local llama-server: no real API key needed
                    -- Minuet expects an env var name here; TERM always exists.
                    api_key = "TERM",
                    name = "Phi-3.5-mini (llama-server)",
                    end_point = "http://127.0.0.1:26122/v1/completions",
                    model = "Phi-3.5-mini-instruct-Q8_0.gguf",
                    optional = {
                        max_tokens = 256,
                        stop = { "\n\n" },
                        top_p = 0.9,
                    },
                    template = {
                        -- Simple Phi-3.5 layout: prefix + cursor marker + suffix
                        prompt = function(context_before_cursor, context_after_cursor, _)
                            return context_before_cursor
                                .. "<cursor>"
                                .. context_after_cursor
                        end,
                        suffix = false,
                    },
                },
            },
            virtualtext = {
                auto_trigger_ft = { "*" },
                keymap = {
                    accept = "<Tab>",
                    accept_line = "<C-y>",
                    next = "<C-n>",
                    prev = "<C-p>",
                    dismiss = "<C-e>",
                },
            },
        },
    },
    {
        "nomnivore/ollama.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
        },
        cmd = { "Ollama", "OllamaModel", "OllamaServe", "OllamaServeStop" },
        keys = {
            {
                "<leader>oo",
                ":<c-u>lua require('ollama').prompt()<cr>",
                desc = "Ollama prompt",
                mode = { "n", "v" },
            },
            {
                "<leader>oG",
                ":<c-u>lua require('ollama').prompt('Generate_Code')<cr>",
                desc = "Ollama generate code",
                mode = { "n", "v" },
            },
        },
        opts = {
            model = "Phi-3.5-mini-instruct-Q8_0",
            url = "http://127.0.0.1:26122",
        },
    }
})
