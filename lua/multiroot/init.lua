local M = {}

local function emit(event, data)
  vim.api.nvim_exec_autocmds("User", { pattern = event, data = data })
end

function M.setup(opts)
  local config = require("multiroot.config")
  config.setup(opts)

  require("multiroot.lsp").setup()
  require("multiroot.session").setup()
  require("multiroot.commands").setup()

  local cfg = config.get()
  if cfg.auto_load then
    vim.api.nvim_create_autocmd("VimEnter", {
      group = vim.api.nvim_create_augroup("MultirootAutoLoad", { clear = true }),
      once = true,
      callback = function()
        local workspace = require("multiroot.workspace")
        local file = workspace.find_in_cwd(cfg.workspace_file)
        if file then
          M.open(file)
        end
      end,
    })
  end
end

function M.open(path)
  local config = require("multiroot.config").get()
  local workspace = require("multiroot.workspace")
  local state = require("multiroot.state")
  local lsp = require("multiroot.lsp")
  local session = require("multiroot.session")
  local recent = require("multiroot.recent")
  local util = require("multiroot.util")

  local ws, err = workspace.read(path)
  if not ws then
    util.notify(err, vim.log.levels.ERROR)
    return false
  end
  if #ws.folders == 0 then
    util.notify("workspace has no folders", vim.log.levels.WARN)
    return false
  end

  if state.is_active() then
    M.close({ silent = true })
  end

  state.set(ws)
  local primary = ws.folders[1]
  if vim.fn.isdirectory(primary) == 1 then
    vim.api.nvim_set_current_dir(primary)
  end
  if config.lsp.enabled then
    lsp.sync_all()
  end
  recent.add(ws)
  emit("MultirootLoaded", ws)
  if config.session.autoload then
    session.load(ws.name)
  end
  util.notify("opened " .. ws.name .. " (" .. #ws.folders .. " folders)")
  return true
end

function M.close(opts)
  opts = opts or {}
  local config = require("multiroot.config").get()
  local state = require("multiroot.state")
  local session = require("multiroot.session")
  local lsp = require("multiroot.lsp")
  local util = require("multiroot.util")
  if not state.is_active() then
    return false
  end
  if config.session.autosave then
    session.save()
  end
  if config.lsp.enabled then
    lsp.remove_all(state.folders())
  end
  local ws = state.current
  state.clear()
  emit("MultirootClosed", ws)
  if not opts.silent then
    util.notify("closed " .. ws.name)
  end
  return true
end

function M.create(path, folders, name)
  local workspace = require("multiroot.workspace")
  local util = require("multiroot.util")
  local abs = {}
  for _, f in ipairs(folders) do
    table.insert(abs, util.expand(f))
  end
  local ws = {
    name = name or vim.fn.fnamemodify(util.expand(path), ":t:r"),
    folders = abs,
  }
  local ok, err = workspace.write(path, ws)
  if not ok then
    util.notify(err or "failed to write workspace", vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.add_folder(path)
  local state = require("multiroot.state")
  local workspace = require("multiroot.workspace")
  local lsp = require("multiroot.lsp")
  local util = require("multiroot.util")
  if not state.is_active() then
    util.notify("no workspace open", vim.log.levels.WARN)
    return false
  end
  path = util.expand(path)
  for _, f in ipairs(state.current.folders) do
    if f == path then
      util.notify("folder already in workspace")
      return false
    end
  end
  table.insert(state.current.folders, path)
  workspace.write(state.current.file, state.current)
  lsp.sync_all()
  util.notify("added " .. path)
  return true
end

function M.remove_folder(path)
  local state = require("multiroot.state")
  local workspace = require("multiroot.workspace")
  local lsp = require("multiroot.lsp")
  local util = require("multiroot.util")
  if not state.is_active() then
    return false
  end
  path = util.expand(path)
  for i, f in ipairs(state.current.folders) do
    if f == path then
      table.remove(state.current.folders, i)
      workspace.write(state.current.file, state.current)
      lsp.remove_all({ path })
      util.notify("removed " .. path)
      return true
    end
  end
  util.notify("folder not in workspace", vim.log.levels.WARN)
  return false
end

function M.current()
  return require("multiroot.state").current
end

function M.folders()
  return require("multiroot.state").folders()
end

function M.files()
  require("multiroot.picker").files()
end

function M.grep()
  require("multiroot.picker").grep()
end

function M.recent()
  require("multiroot.picker").pick_recent()
end

return M
