vim.api.nvim_create_autocmd("FileType", {
	pattern = "oil",
	callback = function()
		vim.opt_local.colorcolumn = ""
	end,
})

return {
	{
		"stevearc/oil.nvim",
		opts = {},
		-- Optional dependencies
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("oil").setup({
				-- use_default_keymaps = false,
				confirmation = {
					border = "rounded",
				},
				float = {
					border = "rounded",
				},
				-- SSH optimizations: keep SCP connections alive
				extra_scp_args = { "-o", "ControlMaster=auto", "-o", "ControlPersist=10m" },
				keymaps = {
					["<C-l>"] = false,
					["<C-r>"] = "actions.refresh",
					-- Quick SSH: open remote directory prompt
					["gs"] = { "actions.cd", desc = "Open SSH remote directory" },
				},
				view_options = {
					show_hidden = true,
				},
				-- SSH adapter config
				ssh = {
					border = "rounded",
				},
			})
		end,
	},
}
