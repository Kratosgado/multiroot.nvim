local state = require("multiroot.state")
local util = require("multiroot.util")

local M = {}

local saved = {}

function M.apply()
  if not state.is_active() then
    return
  end
  saved = {}
  local opts = state.current.vim_options or {}
  for key, value in pairs(opts) do
    local ok_read, prev = pcall(function()
      return vim.o[key]
    end)
    if ok_read then
      saved[key] = prev
      local ok_write, err = pcall(function()
        vim.o[key] = value
      end)
      if not ok_write then
        util.notify("vim_options: cannot set " .. key .. ": " .. tostring(err), vim.log.levels.WARN)
        saved[key] = nil
      end
    end
  end
end

function M.restore()
  for key, prev in pairs(saved) do
    pcall(function()
      vim.o[key] = prev
    end)
  end
  saved = {}
end

return M
