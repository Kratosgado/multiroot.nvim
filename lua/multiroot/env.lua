local state = require("multiroot.state")
local util = require("multiroot.util")

local M = {}

local SENTINEL = "\0"
local saved = {}

function M.apply()
  if not state.is_active() then
    return
  end
  saved = {}
  for k, v in pairs(state.current.env or {}) do
    local prev = vim.env[k]
    saved[k] = prev == nil and SENTINEL or prev
    vim.env[k] = v
  end
end

function M.restore()
  for k, prev in pairs(saved) do
    if prev == SENTINEL then
      vim.env[k] = nil
    else
      vim.env[k] = prev
    end
  end
  saved = {}
end

--- Returns the env delta to pass to a spawned process for a given profile name.
--- Only includes the named profile's vars (base env is inherited from vim.env).
--- Returns nil if no profile requested or profile doesn't exist.
function M.resolve(profile)
  if not profile or profile == "" then
    return nil
  end
  if not state.is_active() then
    return nil
  end
  local envs = state.current.envs or {}
  local map = envs[profile]
  if not map then
    util.notify("unknown env profile '" .. profile .. "'", vim.log.levels.WARN)
    return nil
  end
  local copy = {}
  for k, v in pairs(map) do
    copy[k] = v
  end
  return copy
end

function M.profiles()
  if not state.is_active() then
    return {}
  end
  local names = {}
  for name, _ in pairs(state.current.envs or {}) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

return M
