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
            context_window = 4096,
            throttle = 500,
            debounce = 300,
            provider_options = {
                openai_fim_compatible = {
                    api_key = "TERM",
                    name = "qwen2.5-coder-7b-instruct-q8_0",
                    end_point = "http://127.0.0.1:26122/v1/completions",
                    model = "qwen2.5-coder-7b-instruct-q8_0",
                    optional = {
                        max_tokens = 256,
                        stop = { "\n\n" },
                        top_p = 0.9,
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
            model = "qwen2.5-coder-7b-instruct-q8_0",
            url = "http://127.0.0.1:26122",
        },
    }
})
