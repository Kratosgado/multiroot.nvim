local util = require("multiroot.util")

local M = {}

function M.read(path)
  path = util.expand(path)
  local data, err = util.read_file(path)
  if not data then
    return nil, err
  end
  local ok, decoded = pcall(vim.json.decode, data)
  if not ok then
    return nil, "invalid JSON in " .. path .. ": " .. decoded
  end
  if type(decoded) ~= "table" then
    return nil, "workspace file must contain a JSON object"
  end
  local folders = {}
  for _, f in ipairs(decoded.folders or {}) do
    if type(f) == "string" then
      table.insert(folders, util.expand(f))
    elseif type(f) == "table" and type(f.path) == "string" then
      table.insert(folders, util.expand(f.path))
    end
  end
  local name = decoded.name
  if type(name) ~= "string" or name == "" then
    name = vim.fn.fnamemodify(path, ":t:r")
    if name == "" then
      name = vim.fn.fnamemodify(path, ":h:t")
    end
  end
  return {
    name = name,
    file = path,
    folders = folders,
    settings = decoded.settings or {},
  }
end

function M.write(path, ws)
  path = util.expand(path)
  local payload = {
    name = ws.name,
    folders = ws.folders,
  }
  if ws.settings and next(ws.settings) then
    payload.settings = ws.settings
  end
  local encoded = util.encode_pretty(payload)
  if not encoded then
    return false, "failed to encode workspace"
  end
  return util.write_file(path, encoded)
end

function M.find_in_cwd(name)
  local candidate = vim.fn.getcwd() .. "/" .. name
  if util.exists(candidate) then
    return candidate
  end
  return nil
end

return M
