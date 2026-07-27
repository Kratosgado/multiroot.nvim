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
  require("multiroot.keymap").setup()
  require("multiroot.auto_lcd").setup()

  local cfg = config.get()
  if cfg.schema and cfg.schema.register then
    require("multiroot.schema").register(cfg)
  end

  if cfg.auto_load then
    local function try_auto_load()
      local workspace = require("multiroot.workspace")
      local file = workspace.find_in_cwd(cfg.workspace_file)
      if file then
        M.open(file)
      end
    end
    if vim.v.vim_did_enter == 1 then
      try_auto_load()
    else
      vim.api.nvim_create_autocmd("VimEnter", {
        group = vim.api.nvim_create_augroup("MultirootAutoLoad", { clear = true }),
        once = true,
        callback = try_auto_load,
      })
    end
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
  require("multiroot.env").apply()
  if config.lsp.enabled then
    lsp.sync_all()
    require("multiroot.lsp_settings").apply()
  end
  recent.add(ws)
  emit("MultirootLoaded", ws)
  if config.session.autoload then
    session.load(ws.name)
  end
  if config.terminal and config.terminal.autostart then
    require("multiroot.terminal").autostart()
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
  local ws = state.current
  local folders = state.folders()
  if config.on_close and config.on_close.close_terminals then
    require("multiroot.terminal").close_all_for_current()
  end
  local wiped, skipped = 0, 0
  if config.on_close and config.on_close.wipe_buffers then
    wiped, skipped = require("multiroot.buffers").wipe_folders(folders)
  end
  if config.lsp.enabled then
    require("multiroot.lsp_settings").restore()
    lsp.remove_all(folders)
  end
  require("multiroot.env").restore()
  state.clear()
  emit("MultirootClosed", ws)
  if not opts.silent then
    local msg = "closed " .. ws.name
    if wiped > 0 then
      msg = msg .. " (" .. wiped .. " buffers wiped"
      if skipped and skipped > 0 then
        msg = msg .. ", " .. skipped .. " unsaved kept"
      end
      msg = msg .. ")"
    end
    util.notify(msg)
  end
  return true
end

function M.create(folders, name)
  local workspace = require("multiroot.workspace")
  local util = require("multiroot.util")
  local config = require("multiroot.config").get()
  local path = vim.fn.getcwd() .. "/" .. config.workspace_file
  if util.exists(path) then
    util.notify(config.workspace_file .. " already exists (use :WorkspaceEdit)", vim.log.levels.ERROR)
    return false
  end
  local abs = {}
  for _, f in ipairs(folders or {}) do
    table.insert(abs, util.expand(f))
  end
  if #abs == 0 then
    table.insert(abs, util.expand(vim.fn.getcwd()))
  end
  local ws = {
    name = name or vim.fn.fnamemodify(vim.fn.getcwd(), ":t"),
    folders = abs,
  }
  local ok, err = workspace.write(path, ws)
  if not ok then
    util.notify(err or "failed to write workspace", vim.log.levels.ERROR)
    return false
  end
  M.open(path)
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

function M.terminal(folder)
  if folder and folder ~= "" then
    require("multiroot.terminal").open_folder(folder)
  else
    require("multiroot.terminal").pick_folder()
  end
end

function M.terminal_run(name)
  if name and name ~= "" then
    require("multiroot.terminal").run_named(name)
  else
    require("multiroot.terminal").pick_named()
  end
end

function M.task(name)
  if name and name ~= "" then
    require("multiroot.task").run_named(name)
  else
    require("multiroot.task").pick()
  end
end

function M.statusline(opts)
  return require("multiroot.statusline").get(opts)
end

--- Absolute path of the deepest workspace folder containing `bufnr`'s file.
--- Falls back to the first workspace folder when the buffer is unnamed or
--- lives outside every folder. Returns nil when no workspace is open.
function M.folder_for_buffer(bufnr)
  local util = require("multiroot.util")
  local resolved = util.folder_for_buffer(bufnr)
  if resolved then
    return resolved
  end
  local folders = require("multiroot.state").folders()
  return folders[1]
end

function M.edit()
  local state = require("multiroot.state")
  local util = require("multiroot.util")
  if not state.is_active() then
    util.notify("no workspace open", vim.log.levels.WARN)
    return
  end
  vim.cmd("edit " .. vim.fn.fnameescape(state.current.file))
end

function M.schema_path()
  return require("multiroot.schema").path()
end

function M.git(bufnr)
  require("multiroot.git").open(bufnr)
end

function M.reload()
  local state = require("multiroot.state")
  local util = require("multiroot.util")
  if not state.is_active() then
    util.notify("no workspace open", vim.log.levels.WARN)
    return false
  end
  local path = state.current.file
  M.close({ silent = true })
  return M.open(path)
end

return M
