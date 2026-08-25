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
        env = type(t.env) == "string" and t.env or nil,
      })
    end
  end
  local tasks = {}
  for _, t in ipairs(decoded.tasks or {}) do
    if type(t) == "table" and type(t.name) == "string" and type(t.cmd) == "string" then
      table.insert(tasks, {
        name = t.name,
        cmd = t.cmd,
        description = type(t.description) == "string" and t.description or nil,
        folder = type(t.folder) == "string" and t.folder or nil,
        position = type(t.position) == "string" and t.position or nil,
        interactive = t.interactive == true,
        env = type(t.env) == "string" and t.env or nil,
      })
    end
  end
  local stacks = {}
  for _, s in ipairs(decoded.stacks or {}) do
    if type(s) == "table" and type(s.name) == "string" and type(s.tasks) == "table" then
      local task_names = {}
      for _, tn in ipairs(s.tasks) do
        if type(tn) == "string" then
          table.insert(task_names, tn)
        end
      end
      table.insert(stacks, {
        name = s.name,
        description = type(s.description) == "string" and s.description or nil,
        tasks = task_names,
        layout = type(s.layout) == "string" and s.layout or "tabs",
      })
    end
  end
  local commands = {}
  for _, c in ipairs(decoded.commands or {}) do
    if type(c) == "table" and type(c.name) == "string" and type(c.action) == "string" then
      table.insert(commands, {
        name = c.name,
        action = c.action,
        desc = type(c.desc) == "string" and c.desc or ("Workspace: " .. c.name),
      })
    end
  end
  local function coerce_env_map(t)
    local m = {}
    if type(t) ~= "table" then
      return m
    end
    for k, v in pairs(t) do
      if type(k) == "string" and (type(v) == "string" or type(v) == "number" or type(v) == "boolean") then
        m[k] = tostring(v)
      end
    end
    return m
  end
  local env = coerce_env_map(decoded.env)
  local envs = {}
  if type(decoded.envs) == "table" then
    for profile, map in pairs(decoded.envs) do
      if type(profile) == "string" then
        envs[profile] = coerce_env_map(map)
      end
    end
  end
  local keymaps = {}
  for _, k in ipairs(decoded.keymaps or {}) do
    if type(k) == "table" and type(k.lhs) == "string" and type(k.rhs) == "string" then
      table.insert(keymaps, {
        lhs = k.lhs,
        rhs = k.rhs,
        mode = k.mode,
        desc = type(k.desc) == "string" and k.desc or nil,
      })
    end
  end
  return {
    name = name,
    file = path,
    folders = folders,
    settings = decoded.settings or {},
    terminals = terminals,
    tasks = tasks,
    stacks = stacks,
    commands = commands,
    env = env,
    envs = envs,
    keymaps = keymaps,
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
  if ws.envs and next(ws.envs) then
    payload.envs = ws.envs
  end
  if ws.stacks and #ws.stacks > 0 then
    payload.stacks = ws.stacks
  end
  if ws.commands and #ws.commands > 0 then
    payload.commands = ws.commands
  end
  if ws.keymaps and #ws.keymaps > 0 then
    payload.keymaps = ws.keymaps
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
