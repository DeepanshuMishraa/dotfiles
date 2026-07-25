local M = {}

--- Get the target directory: Oil's current dir, current buffer's parent, or cwd
local function get_target_dir()
	local ok, oil = pcall(require, "oil")
	if ok and oil then
		local dir = oil.get_current_dir()
		if dir then
			return dir
		end
	end

	local buf = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(buf)
	if path and path ~= "" then
		local stat = vim.loop.fs_stat(path)
		if stat and stat.type == "file" then
			return vim.fn.fnamemodify(path, ":h")
		end
	end

	return vim.fn.getcwd()
end

--- Create a new file in the target directory
function M.newfile()
	local dir = get_target_dir()
	vim.ui.input({ prompt = "New file name: ", default = dir .. "/" }, function(name)
		if not name or name == "" then
			return
		end
		local expanded = vim.fn.expand(name)
		local full_path = vim.fn.fnamemodify(expanded, ":p")

		local parent_dir = vim.fn.fnamemodify(full_path, ":h")
		local ok = vim.fn.mkdir(parent_dir, "p")
		if ok == 0 then
			vim.notify("Failed to create directory: " .. parent_dir, vim.log.levels.ERROR)
			return
		end

		local fd = vim.loop.fs_open(full_path, "w", 438)
		if not fd then
			vim.notify("Failed to create file: " .. full_path, vim.log.levels.ERROR)
			return
		end
		vim.loop.fs_close(fd)

		vim.notify("Created file: " .. full_path, vim.log.levels.INFO)
		vim.cmd("edit " .. vim.fn.fnameescape(full_path))
	end)
end

--- Create a new directory in the target directory
function M.newfolder()
	local dir = get_target_dir()
	vim.ui.input({ prompt = "New folder name: ", default = dir .. "/" }, function(name)
		if not name or name == "" then
			return
		end
		local expanded = vim.fn.expand(name)
		local full_path = vim.fn.fnamemodify(expanded, ":p")

		local ok = vim.fn.mkdir(full_path, "p")
		if ok == 0 then
			vim.notify("Failed to create folder: " .. full_path, vim.log.levels.ERROR)
			return
		end

		vim.notify("Created folder: " .. full_path, vim.log.levels.INFO)

		-- Refresh Oil if we're in an Oil buffer
		local ok_oil, oil = pcall(require, "oil")
		if ok_oil and oil then
			local cur_dir = oil.get_current_dir()
			if cur_dir and vim.startswith(full_path, cur_dir) then
				oil.open(cur_dir)
			end
		end
	end)
end

-- Register :Newfile and :Newfolder commands
vim.api.nvim_create_user_command("Newfile", M.newfile, { desc = "Create a new file in the current directory" })
vim.api.nvim_create_user_command("Newfolder", M.newfolder, { desc = "Create a new folder in the current directory" })

return M

