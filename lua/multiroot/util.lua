local M = {}

M.uv = vim.uv or vim.loop

function M.expand(path)
  local abs = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
  return (abs:gsub("/$", ""))
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
  local path = M.expand(name)
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

function M.encode_pretty(tbl)
  local ok, encoded = pcall(vim.json.encode, tbl)
  if not ok then
    return nil, encoded
  end
  return encoded
end

return M
