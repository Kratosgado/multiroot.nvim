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
  local terminals = {}
  for _, t in ipairs(decoded.terminals or {}) do
    if type(t) == "table" and type(t.name) == "string" then
      table.insert(terminals, {
        name = t.name,
        folder = type(t.folder) == "string" and t.folder or nil,
        cmd = type(t.cmd) == "string" and t.cmd or nil,
        position = type(t.position) == "string" and t.position or nil,
        autostart = t.autostart == true,
      })
    end
  end
  local tasks = {}
  for _, t in ipairs(decoded.tasks or {}) do
    if type(t) == "table" and type(t.name) == "string" and type(t.cmd) == "string" then
      table.insert(tasks, {
        name = t.name,
        cmd = t.cmd,
        folder = type(t.folder) == "string" and t.folder or nil,
        position = type(t.position) == "string" and t.position or nil,
        interactive = t.interactive == true,
      })
    end
  end
  local env = {}
  if type(decoded.env) == "table" then
    for k, v in pairs(decoded.env) do
      if type(k) == "string" and (type(v) == "string" or type(v) == "number" or type(v) == "boolean") then
        env[k] = tostring(v)
      end
    end
  end
  return {
    name = name,
    file = path,
    folders = folders,
    settings = decoded.settings or {},
    terminals = terminals,
    tasks = tasks,
    env = env,
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
  if ws.terminals and #ws.terminals > 0 then
    payload.terminals = ws.terminals
  end
  if ws.tasks and #ws.tasks > 0 then
    payload.tasks = ws.tasks
  end
  if ws.env and next(ws.env) then
    payload.env = ws.env
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
