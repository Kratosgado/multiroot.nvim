local state = require("multiroot.state")
local util = require("multiroot.util")

local M = {}

M.icon = ""
M.separator = ":"

local function current_folder_of_buffer(bufnr)
  bufnr = bufnr or 0
  local name = vim.api.nvim_buf_get_name(bufnr)
  if not name or name == "" then
    return nil
  end
  local path = util.expand(name)
  local best
  for _, f in ipairs(state.folders()) do
    local prefix = f:sub(-1) == "/" and f or f .. "/"
    if path == f or path:sub(1, #prefix) == prefix then
      if not best or #f > #best then
        best = f
      end
    end
  end
  return best
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
  table.insert(parts, state.current.name)
  if show_folder then
    local folder = current_folder_of_buffer(opts.bufnr)
    if folder then
      table.insert(parts, M.separator .. vim.fn.fnamemodify(folder, ":t"))
    end
  end
  return table.concat(parts, " "):gsub("%s+" .. M.separator, M.separator)
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
