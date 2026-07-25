--- dipxsy/remote.lua
--- SSH remote connection management for Neovim.
--- Provides host discovery from ~/.ssh/config, a Telescope picker,
--- Oil integration for browsing, and helpers for SSHFS + terminal access.

local M = {}

--- Resolve glob patterns in include paths relative to the config directory.
--- Supports basic glob patterns (*, ?) and ~/ expansion.
---@param pattern string
---@param config_dir string
---@return string[]
local function resolve_include(pattern, config_dir)
  -- Expand ~/ to home directory
  pattern = pattern:gsub("^~/?", vim.fn.expand("~") .. "/")

  if not vim.startswith(pattern, "/") then
    pattern = config_dir .. "/" .. pattern
  end

  -- Simple glob expansion using vim.fn.glob
  local files = vim.fn.glob(pattern, false, true)
  return files
end

--- Parse an SSH config file (or raw lines) and return a list of hosts.
--- Supports Include directives by recursively parsing included files.
--- Supports Host, HostName, User, Port, IdentityFile directives.
---@param config_path_or_lines string|string[]
---@param visited table<string,boolean>|nil
---@return { name: string, hostname: string, user: string|nil, port: string|nil, identity_file: string|nil, raw: table<string,string> }[]
function M.parse_ssh_config(config_path_or_lines, visited)
  config_path_or_lines = config_path_or_lines or vim.fn.expand("~/.ssh/config")
  visited = visited or {}

  local lines
  local config_dir
  if type(config_path_or_lines) == "string" then
    if not vim.uv.fs_stat(config_path_or_lines) then
      return {}
    end
    local abs = vim.fn.fnamemodify(config_path_or_lines, ":p")
    if visited[abs] then
      return {}
    end
    visited[abs] = true
    lines = vim.fn.readfile(config_path_or_lines)
    config_dir = vim.fn.fnamemodify(abs, ":h")
  else
    lines = config_path_or_lines
    config_dir = vim.fn.expand("~/.ssh")
  end

  local hosts = {}
  local current_host = nil
  local current_props = {}

  for _, line in ipairs(lines) do
    -- Strip comments
    local clean = line:gsub("%s*#.*$", "")
    if clean ~= "" then
      local key, value = clean:match("^%s*(%S+)%s+(.-)%s*$")
      if key and value then
        local lower_key = key:lower()

        if lower_key == "host" then
          -- Save previous host block
          if current_host and current_host ~= "*" then
            current_props.name = current_host
            table.insert(hosts, vim.deepcopy(current_props))
          end
          current_host = value
          current_props = {}
        elseif lower_key == "include" then
          -- Recursively parse included files
          local included = resolve_include(value, config_dir)
          for _, inc_path in ipairs(included) do
            local inc_hosts = M.parse_ssh_config(inc_path, visited)
            for _, h in ipairs(inc_hosts) do
              table.insert(hosts, h)
            end
          end
        elseif current_host then
          current_props[lower_key] = value
        end
      end
    end
  end

  -- Don't forget the last host block
  if current_host and current_host ~= "*" then
    current_props.name = current_host
    table.insert(hosts, current_props)
  end

  -- Resolve hostname, user, port into display-friendly fields
  local resolved = {}
  local seen = {}
  for _, h in ipairs(hosts) do
    local key = h.name .. "@" .. (h.hostname or h.name) .. ":" .. (h.port or "22")
    if not seen[key] then
      seen[key] = true
      table.insert(resolved, {
        name = h.name,
        hostname = h.hostname or h.name,
        user = h.user or nil,
        port = h.port or nil,
        identity_file = h.identityfile or nil,
        raw = h,
      })
    end
  end

  table.sort(resolved, function(a, b)
    return a.name:lower() < b.name:lower()
  end)

  return resolved
end

--- Build an SSH connection string for a host entry.
---@param entry { name: string, hostname: string, user: string|nil, port: string|nil }
---@return string
function M.host_to_ssh_string(entry)
  local parts = {}
  if entry.user then
    table.insert(parts, entry.user .. "@")
  end
  table.insert(parts, entry.hostname)
  if entry.port then
    table.insert(parts, " -p " .. entry.port)
  end
  return table.concat(parts, "")
end

--- Build an Oil-friendly ssh:// URL for a host entry.
---@param entry { name: string, hostname: string, user: string|nil, port: string|nil }
---@param path string
---@return string
function M.host_to_oil_url(entry, path)
  path = path or "."
  local parts = { "ssh://" }
  if entry.user then
    table.insert(parts, entry.user .. "@")
  end
  table.insert(parts, entry.hostname)
  if entry.port then
    table.insert(parts, ":" .. entry.port)
  end
  table.insert(parts, "/" .. path)
  return table.concat(parts, "")
end

--- Open Oil file browser on a remote host.
---@param entry { name: string, hostname: string, user: string|nil, port: string|nil }
---@param path string|nil
function M.open_oil(entry, path)
  local url = M.host_to_oil_url(entry, path)
  vim.cmd("Oil " .. url)
end

--- Open a terminal split with an SSH connection to the host.
---@param entry { name: string, hostname: string, user: string|nil, port: string|nil }
function M.open_terminal(entry)
  local ssh_str = M.host_to_ssh_string(entry)
  vim.cmd("split | terminal ssh " .. ssh_str)
end

--- Open a floating terminal with an SSH connection.
---@param entry { name: string, hostname: string, user: string|nil, port: string|nil }
function M.open_floating_terminal(entry)
  local ssh_str = M.host_to_ssh_string(entry)
  local snacks = require("snacks")
  -- Check if Snacks terminal exists
  if snacks and snacks.terminal then
    snacks.terminal("ssh " .. ssh_str, { border = "rounded" })
  else
    -- Fallback to vim.cmd terminal
    vim.cmd("split +terminal ssh " .. ssh_str)
  end
end

--- Telescope picker for SSH hosts.
--- Lets you pick a host and then choose an action (Oil browse / terminal).
function M.show_hosts_picker()
  local hosts = M.parse_ssh_config()
  if #hosts == 0 then
    vim.notify("No SSH hosts found in ~/.ssh/config", vim.log.levels.WARN)
    return
  end

  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local conf = require("telescope.config").values

  local picker = pickers.new({}, {
    prompt_title = "SSH Hosts",
    finder = finders.new_table({
      results = hosts,
      entry_maker = function(entry)
        local display_parts = { entry.name }
        if entry.user then
          table.insert(display_parts, " (" .. entry.user .. "@" .. entry.hostname .. ")")
        else
          table.insert(display_parts, " (" .. entry.hostname .. ")")
        end
        if entry.port then
          table.insert(display_parts, " :" .. entry.port)
        end
        return {
          value = entry,
          display = table.concat(display_parts, ""),
          ordinal = entry.name .. " " .. (entry.hostname or "") .. " " .. (entry.user or ""),
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      -- Default: <CR> opens Oil browser on the remote host
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          M.open_oil(selection.value)
        end
      end)

      -- <C-t> opens a terminal split
      map("i", "<C-t>", function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          M.open_terminal(selection.value)
        end
      end)

      -- <C-f> opens a floating terminal
      map("i", "<C-f>", function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if selection then
          M.open_floating_terminal(selection.value)
        end
      end)

      -- <C-h> shows host details
      map("i", "<C-h>", function()
        local selection = action_state.get_selected_entry()
        if selection then
          local e = selection.value
          local lines = {
            "Host:        " .. e.name,
            "Hostname:    " .. e.hostname,
            "User:        " .. (e.user or "(default)"),
            "Port:        " .. (e.port or "22"),
            "Identity:    " .. (e.identity_file or "(default)"),
          }
          vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
        end
      end)

      return true
    end,
  })

  picker:find()
end

return M
