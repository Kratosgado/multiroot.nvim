local state = require("multiroot.state")
local util = require("multiroot.util")

local M = {}

local SENTINEL = "\0"
local saved = {}
local active_profile = nil

local function snapshot_and_set(map)
  for k, v in pairs(map or {}) do
    if saved[k] == nil then
      local prev = vim.env[k]
      saved[k] = prev == nil and SENTINEL or prev
    end
    vim.env[k] = v
  end
end

function M.apply()
  if not state.is_active() then
    return
  end
  saved = {}
  active_profile = nil
  snapshot_and_set(state.current.env)
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
  active_profile = nil
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

function M.active()
  return active_profile
end

function M.switch(name)
  if not state.is_active() then
    util.notify("no workspace open", vim.log.levels.WARN)
    return false
  end
  local envs = state.current.envs or {}
  local target = envs[name]
  if not target then
    util.notify("no env profile named '" .. tostring(name) .. "'", vim.log.levels.WARN)
    return false
  end
  M.restore()
  snapshot_and_set(state.current.env)
  snapshot_and_set(target)
  active_profile = name
  util.notify("env profile: " .. name)
  return true
end

function M.reset()
  if not state.is_active() then
    return
  end
  M.restore()
  snapshot_and_set(state.current.env)
  util.notify("env profile: (base)")
end

function M.pick()
  local names = M.profiles()
  if #names == 0 then
    util.notify("workspace defines no env profiles")
    return
  end
  local items = { "(base)" }
  for _, n in ipairs(names) do
    table.insert(items, n)
  end
  vim.ui.select(items, {
    prompt = "Env profile:",
    format_item = function(item)
      if item == active_profile then
        return "* " .. item
      elseif item == "(base)" and active_profile == nil then
        return "* " .. item
      end
      return "  " .. item
    end,
  }, function(choice)
    if not choice then
      return
    end
    if choice == "(base)" then
      M.reset()
    else
      M.switch(choice)
    end
  end)
end

return M
