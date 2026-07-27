local config = require("multiroot.config")
local state = require("multiroot.state")
local util = require("multiroot.util")

local M = {}

local function default_open(cwd)
  local ok_neogit, neogit = pcall(require, "neogit")
  if ok_neogit and neogit and neogit.open then
    neogit.open({ cwd = cwd })
    return true
  end
  util.notify(
    "no git integration configured; set opts.git.open = function(cwd) ... end",
    vim.log.levels.WARN
  )
  return false
end

--- Open the configured git tool at the buffer's workspace folder.
function M.open(bufnr)
  if not state.is_active() then
    util.notify("no workspace open", vim.log.levels.WARN)
    return
  end
  local folder = util.folder_for_buffer(bufnr) or state.folders()[1]
  if not folder then
    util.notify("could not resolve a workspace folder for this buffer", vim.log.levels.WARN)
    return
  end
  local fn = config.get().git and config.get().git.open
  if type(fn) == "function" then
    local ok, err = pcall(fn, folder)
    if not ok then
      util.notify("git.open callback failed: " .. tostring(err), vim.log.levels.ERROR)
    end
    return
  end
  default_open(folder)
end

return M
