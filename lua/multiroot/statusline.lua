local state = require("multiroot.state")
local util = require("multiroot.util")

local M = {}

M.icon = ""
M.separator = ":"

local function current_folder_of_buffer(bufnr)
  return util.folder_for_buffer(bufnr)
end

function M.get(opts)
  if not state.is_active() then
    return ""
  end
  opts = opts or {}
  local show_folder = opts.folder ~= false
  local parts = {}
  if opts.icon ~= false then
    table.insert(parts, M.icon)
  end
  local name = state.current.name
  if show_folder then
    local folder = current_folder_of_buffer(opts.bufnr)
    if folder then
      name = name .. M.separator .. vim.fn.fnamemodify(folder, ":t")
    end
  end
  table.insert(parts, name)
  return table.concat(parts, " ")
end

function M.name()
  if not state.is_active() then
    return ""
  end
  return state.current.name
end

function M.folder(bufnr)
  local f = current_folder_of_buffer(bufnr)
  return f and vim.fn.fnamemodify(f, ":t") or ""
end

return M
