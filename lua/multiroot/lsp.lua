local state = require("multiroot.state")

local M = {}

local function get_clients()
  if vim.lsp.get_clients then
    return vim.lsp.get_clients()
  end
  return vim.lsp.get_active_clients()
end

local function existing_folders(client)
  local set = {}
  for _, wf in ipairs(client.workspace_folders or {}) do
    local ok, fname = pcall(vim.uri_to_fname, wf.uri)
    if ok then
      set[fname:gsub("/$", "")] = true
    end
  end
  return set
end

local function add_folders_to_client(client, folders)
  if not client or not client.workspace_folders then
    return
  end
  local existing = existing_folders(client)
  local to_add = {}
  for _, folder in ipairs(folders) do
    if not existing[folder] and vim.fn.isdirectory(folder) == 1 then
      table.insert(to_add, {
        uri = vim.uri_from_fname(folder),
        name = folder,
      })
    end
  end
  if #to_add == 0 then
    return
  end
  client.notify("workspace/didChangeWorkspaceFolders", {
    event = { added = to_add, removed = {} },
  })
  for _, wf in ipairs(to_add) do
    table.insert(client.workspace_folders, wf)
  end
end

local function remove_folders_from_client(client, folders)
  if not client or not client.workspace_folders then
    return
  end
  local target = {}
  for _, f in ipairs(folders) do
    target[f] = true
  end
  local to_remove = {}
  local keep = {}
  for _, wf in ipairs(client.workspace_folders) do
    local ok, fname = pcall(vim.uri_to_fname, wf.uri)
    local normalized = ok and fname:gsub("/$", "") or nil
    if normalized and target[normalized] then
      table.insert(to_remove, { uri = wf.uri, name = wf.name })
    else
      table.insert(keep, wf)
    end
  end
  if #to_remove == 0 then
    return
  end
  client.notify("workspace/didChangeWorkspaceFolders", {
    event = { added = {}, removed = to_remove },
  })
  client.workspace_folders = keep
end

function M.sync_all()
  if not state.is_active() then
    return
  end
  for _, client in ipairs(get_clients()) do
    add_folders_to_client(client, state.folders())
  end
end

function M.remove_all(folders)
  for _, client in ipairs(get_clients()) do
    remove_folders_from_client(client, folders)
  end
end

function M.setup()
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("MultirootLsp", { clear = true }),
    callback = function(args)
      if not state.is_active() then
        return
      end
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      add_folders_to_client(client, state.folders())
    end,
  })
end

return M
