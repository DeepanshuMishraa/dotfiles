local M = {}
local watcher
local timer

function M.watch()
	if watcher then
		return
	end

	local path = vim.fn.stdpath("config") .. "/lua/herdr-sync.lua"
	local directory = vim.fs.dirname(path)
	watcher = vim.uv.new_fs_event()
	if not watcher then
		return
	end

	timer = vim.uv.new_timer()
	watcher:start(directory, {}, function(error, filename)
		if error or filename ~= "herdr-sync.lua" or not timer then
			return
		end
		timer:stop()
		timer:start(50, 0, vim.schedule_wrap(function()
			package.loaded["herdr-sync"] = nil
			local ok, message = pcall(dofile, path)
			if not ok then
				vim.notify("Hued theme reload failed: " .. tostring(message), vim.log.levels.ERROR)
			end
		end))
	end)

	vim.g.hued_theme_watcher = true
end

return M
