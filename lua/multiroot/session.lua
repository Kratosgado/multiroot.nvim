local config = require("multiroot.config")
local state = require("multiroot.state")
local util = require("multiroot.util")

local M = {}

local function sanitize(name)
  return (name:gsub("[^%w%-_%.]", "_"))
end

local function session_path(name)
  return config.get().data_dir .. "/sessions/" .. sanitize(name) .. ".vim"
end

function M.path_for(name)
  return session_path(name)
end

function M.save()
  if not state.is_active() then
    return
  end
  if not config.get().session.enabled then
    return
  end
  local path = session_path(state.current.name)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local ok, err = pcall(vim.cmd, "mksession! " .. vim.fn.fnameescape(path))
  if not ok then
    util.notify("session save failed: " .. tostring(err), vim.log.levels.WARN)
  end
end

function M.load(name)
  local path = session_path(name)
  if vim.fn.filereadable(path) == 0 then
    return false
  end
  local ok, err = pcall(vim.cmd, "silent! source " .. vim.fn.fnameescape(path))
  if not ok then
    util.notify("session load failed: " .. tostring(err), vim.log.levels.WARN)
    return false
  end
  return true
end

function M.delete(name)
  local path = session_path(name)
  if vim.fn.filereadable(path) == 1 then
    vim.fn.delete(path)
  end
end

function M.setup()
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("MultirootSession", { clear = true }),
    callback = function()
      if config.get().session.autosave then
        M.save()
      end
    end,
  })
end

return M
