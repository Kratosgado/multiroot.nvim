local M = {}

M.uv = vim.uv or vim.loop

function M.expand(path)
  return vim.fn.fnamemodify(vim.fn.expand(path), ":p"):gsub("/$", "")
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

function M.encode_pretty(tbl)
  local ok, encoded = pcall(vim.json.encode, tbl)
  if not ok then
    return nil, encoded
  end
  return encoded
end

return M
