local state = require("multiroot.state")
local util = require("multiroot.util")

local M = {}

-- lsp_name -> original vim.lsp.config[name] snapshot (or vim.NIL if not set)
local snapshots = {}
-- client_id -> original client.settings snapshot (or vim.NIL if not set)
local client_snapshots = {}

local function get_overrides()
  if not state.is_active() then
    return {}
  end
  local settings = state.current.settings or {}
  local overrides = settings.lsp
  if type(overrides) ~= "table" then
    return {}
  end
  return overrides
end

local function get_clients_by_name(name)
  return vim.lsp.get_clients and vim.lsp.get_clients({ name = name })
    or vim.tbl_filter(function(c)
      return c.name == name
    end, vim.lsp.get_active_clients())
end

local function apply_to_clients(name, config_patch)
  if not config_patch.settings then
    return
  end
  for _, client in ipairs(get_clients_by_name(name)) do
    if client_snapshots[client.id] == nil then
      client_snapshots[client.id] = client.settings ~= nil and vim.deepcopy(client.settings) or vim.NIL
    end
    client.settings = vim.tbl_deep_extend("force", client.settings or {}, config_patch.settings)
    client.notify("workspace/didChangeConfiguration", { settings = client.settings })
  end
end

function M.apply()
  local overrides = get_overrides()
  snapshots = {}
  if vim.lsp.config == nil then
    if next(overrides) then
      util.notify("workspace LSP settings need Neovim 0.11+ (vim.lsp.config)", vim.log.levels.WARN)
    end
    return
  end
  for name, patch in pairs(overrides) do
    if type(patch) == "table" then
      local existing = rawget(vim.lsp.config, name)
      snapshots[name] = existing and vim.deepcopy(existing) or vim.NIL
      vim.lsp.config(name, patch)
      apply_to_clients(name, patch)
    end
  end
end

function M.restore()
  if vim.lsp.config ~= nil then
    for name, snap in pairs(snapshots) do
      if snap == vim.NIL then
        pcall(function()
          vim.lsp.config[name] = nil
        end)
      else
        vim.lsp.config(name, snap)
      end
    end
  end
  snapshots = {}
  for id, snap in pairs(client_snapshots) do
    local client = vim.lsp.get_client_by_id(id)
    if client then
      client.settings = snap == vim.NIL and nil or snap
      client.notify("workspace/didChangeConfiguration", { settings = client.settings or {} })
    end
  end
  client_snapshots = {}
end

return M
