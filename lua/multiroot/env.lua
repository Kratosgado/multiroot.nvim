local state = require("multiroot.state")

local M = {}

local SENTINEL = "\0"
local saved = {}

function M.apply()
  if not state.is_active() then
    return
  end
  local env = state.current.env or {}
  saved = {}
  for k, v in pairs(env) do
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

function M.saved_snapshot()
  local snap = {}
  for k, v in pairs(saved) do
    snap[k] = v == SENTINEL and vim.NIL or v
  end
  return snap
end

return M
