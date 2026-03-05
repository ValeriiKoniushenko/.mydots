require'nvim-treesitter.configs'.setup {
	  ensure_installed = { "c", "lua", "vim", "vimdoc", "markdown", "markdown_inline", "cmake", "cpp", "git_config", "git_rebase", "gitattributes" , "gitcommit", "gitignore", "glsl", "html", "xml", "json", "ini", "ssh_config", "vim", "yaml", "bash"},

	  sync_install = false,
	  auto_install = true,

	  highlight = {
		    enable = true,
		    additional_vim_regex_highlighting = false,
	  }
}
