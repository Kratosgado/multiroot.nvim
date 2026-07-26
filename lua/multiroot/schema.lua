local M = {}

local function plugin_root()
  local src = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(src, ":p:h:h:h")
end

function M.path()
  return plugin_root() .. "/schemas/workspace.json"
end

--- Return the schema mapping entry (for jsonls `settings.json.schemas`).
function M.entry(config)
  config = config or {}
  local filename = config.workspace_file or ".nvim-workspace.json"
  local no_dot = (filename:gsub("^%.", ""))
  return {
    fileMatch = { filename, no_dot },
    url = "file://" .. M.path(),
    description = "multiroot.nvim workspace file",
  }
end

local function has_entry(list, entry)
  for _, e in ipairs(list) do
    if e.url == entry.url then
      return true
    end
  end
  return false
end

--- Patch vim.lsp.config for jsonls so .nvim-workspace.json files get schema
--- validation automatically. Also nudges any already-attached jsonls client.
function M.register(config)
  if vim.lsp.config == nil then
    return
  end
  local entry = M.entry(config)
  local ok, existing = pcall(function()
    return vim.lsp.config.jsonls
  end)
  existing = (ok and existing) or {}
  local settings = vim.deepcopy(existing.settings or {})
  settings.json = settings.json or {}
  settings.json.schemas = settings.json.schemas or {}
  if not has_entry(settings.json.schemas, entry) then
    table.insert(settings.json.schemas, entry)
  end
  settings.json.validate = settings.json.validate or { enable = true }
  vim.lsp.config("jsonls", { settings = settings })

  local clients = vim.lsp.get_clients and vim.lsp.get_clients({ name = "jsonls" })
    or vim.tbl_filter(function(c)
      return c.name == "jsonls"
    end, vim.lsp.get_active_clients())
  for _, client in ipairs(clients) do
    client.settings = vim.tbl_deep_extend("force", client.settings or {}, settings)
    client.notify("workspace/didChangeConfiguration", { settings = client.settings })
  end
end

return M
