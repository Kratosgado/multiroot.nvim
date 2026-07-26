local config = require("multiroot.config")
local util = require("multiroot.util")

local M = {}

local MAX_RECENT = 20

local function path()
  return config.get().data_dir .. "/recent.json"
end

function M.read()
  local p = path()
  if not util.exists(p) then
    return {}
  end
  local data, err = util.read_file(p)
  if not data then
    return {}, err
  end
  local ok, list = pcall(vim.json.decode, data)
  if not ok or type(list) ~= "table" then
    return {}
  end
  local cleaned = {}
  for _, entry in ipairs(list) do
    if type(entry) == "table" and type(entry.file) == "string" then
      table.insert(cleaned, entry)
    end
  end
  return cleaned
end

function M.write(list)
  local encoded = util.encode_pretty(list)
  if not encoded then
    return false
  end
  return util.write_file(path(), encoded)
end

function M.add(ws)
  local list = M.read()
  local next_list = {
    {
      name = ws.name,
      file = ws.file,
      folders = ws.folders,
      opened_at = os.time(),
    },
  }
  for _, entry in ipairs(list) do
    if entry.file ~= ws.file and #next_list < MAX_RECENT then
      table.insert(next_list, entry)
    end
  end
  M.write(next_list)
end

function M.remove(file)
  local list = M.read()
  local next_list = {}
  for _, entry in ipairs(list) do
    if entry.file ~= file then
      table.insert(next_list, entry)
    end
  end
  M.write(next_list)
end

return M
