local M = {}

M.uv = vim.uv or vim.loop

function M.expand(path)
  local abs = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
  return (abs:gsub("/$", ""))
end

--- Resolve symlinks so paths from different sources (workspace folders vs.
--- buffer names) can be compared reliably. Falls back to the input when the
--- path doesn't exist yet.
function M.realpath(path)
  return M.uv.fs_realpath(path) or path
end

function M.read_file(path)
  local fd = M.uv.fs_open(path, "r", 438)
  if not fd then
    return nil, "cannot open " .. path
  end
  local stat = M.uv.fs_fstat(fd)
  local data = M.uv.fs_read(fd, stat.size, 0)
  M.uv.fs_close(fd)
  return data
end

function M.write_file(path, data)
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")
  local fd = M.uv.fs_open(path, "w", 420)
  if not fd then
    return false, "cannot write " .. path
  end
  M.uv.fs_write(fd, data, 0)
  M.uv.fs_close(fd)
  return true
end

function M.exists(path)
  return M.uv.fs_stat(path) ~= nil
end

function M.notify(msg, level)
  local config = require("multiroot.config").get()
  if not config.notify then
    return
  end
  vim.notify("multiroot: " .. msg, level or vim.log.levels.INFO)
end

--- Return the deepest workspace folder containing the given buffer's file,
--- or nil if the buffer is unnamed or lives outside every folder.
function M.folder_for_buffer(bufnr)
  local state = require("multiroot.state")
  if not state.is_active() then
    return nil
  end
  bufnr = bufnr or 0
  local name = vim.api.nvim_buf_get_name(bufnr)
  if not name or name == "" then
    return nil
  end
  local path = M.realpath(M.expand(name))
  local best, best_len
  for _, f in ipairs(state.folders()) do
    local rf = M.realpath(f)
    local prefix = rf:sub(-1) == "/" and rf or rf .. "/"
    if path == rf or path:sub(1, #prefix) == prefix then
      if not best_len or #rf > best_len then
        best = f
        best_len = #rf
      end
    end
  end
  return best
end

function M.encode_pretty(tbl)
  local ok, encoded = pcall(vim.json.encode, tbl)
  if not ok then
    return nil, encoded
  end
  return encoded
end

return M
