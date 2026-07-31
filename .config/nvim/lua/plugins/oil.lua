vim.api.nvim_create_autocmd("FileType", {
	pattern = "oil",
	callback = function()
		vim.opt_local.colorcolumn = ""
	end,
})

local function rename_entry()
	local oil = require("oil")
	local entry = oil.get_cursor_entry()
	if not entry or entry.id == 0 then
		vim.notify("Select a file or folder to rename.", vim.log.levels.WARN)
		return
	end

	local old_name = entry.parsed_name
	vim.ui.input({ prompt = "Rename: ", default = old_name }, function(new_name)
		if not new_name or new_name == old_name then
			return
		end
		if new_name == "" or new_name:find("/", 1, true) then
			vim.notify("Enter a non-empty name without '/'. The original name was preserved.", vim.log.levels.ERROR)
			return
		end

		local row = vim.api.nvim_win_get_cursor(0)[1] - 1
		local line = vim.api.nvim_get_current_line()
		local name_start = #line - #old_name
		if name_start < 0 or line:sub(name_start + 1) ~= old_name then
			vim.notify("Oil could not locate the selected name. No file was renamed.", vim.log.levels.ERROR)
			return
		end

		vim.api.nvim_buf_set_text(0, row, name_start, row, #line, { new_name })
		oil.save({ confirm = false })
	end)
end

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
					["r"] = { callback = rename_entry, desc = "Rename entry" },
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
