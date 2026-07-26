local M = {}

local function complete_folders()
  local folders = require("multiroot.state").folders()
  return folders
end

function M.setup()
  local mr = require("multiroot")
  local state = require("multiroot.state")
  local util = require("multiroot.util")

  vim.api.nvim_create_user_command("WorkspaceOpen", function(args)
    if args.args == "" then
      mr.recent()
    else
      mr.open(vim.fn.expand(args.args))
    end
  end, { nargs = "?", complete = "file", desc = "Open a workspace (json file) or pick from recent" })

  vim.api.nvim_create_user_command("WorkspaceClose", function()
    mr.close()
  end, { desc = "Close the current workspace" })

  vim.api.nvim_create_user_command("WorkspaceCreate", function(args)
    if #args.fargs < 1 then
      util.notify("Usage: :WorkspaceCreate <file.json> [folder ...]", vim.log.levels.ERROR)
      return
    end
    local path = args.fargs[1]
    local folders = {}
    for i = 2, #args.fargs do
      table.insert(folders, args.fargs[i])
    end
    if #folders == 0 then
      table.insert(folders, vim.fn.getcwd())
    end
    if mr.create(path, folders) then
      util.notify("created " .. path)
    end
  end, { nargs = "+", complete = "file", desc = "Create a workspace file" })

  vim.api.nvim_create_user_command("WorkspaceAddFolder", function(args)
    mr.add_folder(args.args ~= "" and args.args or vim.fn.getcwd())
  end, { nargs = "?", complete = "dir", desc = "Add a folder to the current workspace" })

  vim.api.nvim_create_user_command("WorkspaceRemoveFolder", function(args)
    mr.remove_folder(args.args)
  end, {
    nargs = 1,
    complete = complete_folders,
    desc = "Remove a folder from the current workspace",
  })

  vim.api.nvim_create_user_command("WorkspaceList", function()
    if not state.is_active() then
      util.notify("no workspace open")
      return
    end
    local lines = { "Workspace: " .. state.current.name, "File:      " .. state.current.file, "Folders:" }
    for _, f in ipairs(state.current.folders) do
      table.insert(lines, "  " .. f)
    end
    vim.api.nvim_echo(vim.tbl_map(function(l)
      return { l .. "\n" }
    end, lines), false, {})
  end, { desc = "Print the current workspace" })

  vim.api.nvim_create_user_command("WorkspaceRecent", function()
    mr.recent()
  end, { desc = "Pick from recent workspaces" })

  vim.api.nvim_create_user_command("WorkspaceFiles", function()
    mr.files()
  end, { desc = "Fuzzy-find files across all workspace folders" })

  vim.api.nvim_create_user_command("WorkspaceGrep", function()
    mr.grep()
  end, { desc = "Live grep across all workspace folders" })

  vim.api.nvim_create_user_command("WorkspaceSaveSession", function()
    require("multiroot.session").save()
    util.notify("session saved")
  end, { desc = "Save the current workspace session" })

  vim.api.nvim_create_user_command("WorkspaceTerm", function(args)
    mr.terminal(args.args)
  end, {
    nargs = "?",
    complete = function()
      local folders = state.folders()
      local names = {}
      for _, f in ipairs(folders) do
        table.insert(names, vim.fn.fnamemodify(f, ":t"))
        table.insert(names, f)
      end
      return names
    end,
    desc = "Open a terminal in a workspace folder (picker if no arg)",
  })

  vim.api.nvim_create_user_command("WorkspaceTermRun", function(args)
    mr.terminal_run(args.args)
  end, {
    nargs = "?",
    complete = function()
      if not state.is_active() then
        return {}
      end
      local names = {}
      for _, t in ipairs(state.current.terminals or {}) do
        table.insert(names, t.name)
      end
      return names
    end,
    desc = "Run a named terminal from the workspace file",
  })

  vim.api.nvim_create_user_command("WorkspaceEdit", function()
    if not state.is_active() then
      util.notify("no workspace open", vim.log.levels.WARN)
      return
    end
    vim.cmd("edit " .. vim.fn.fnameescape(state.current.file))
  end, { desc = "Open the current workspace file for editing" })

  vim.api.nvim_create_user_command("WorkspaceTask", function(args)
    mr.task(args.args)
  end, {
    nargs = "?",
    complete = function()
      if not state.is_active() then
        return {}
      end
      local names = {}
      for _, t in ipairs(state.current.tasks or {}) do
        table.insert(names, t.name)
      end
      return names
    end,
    desc = "Run a workspace task (picker if no arg)",
  })

  vim.api.nvim_create_user_command("WorkspaceTaskList", function()
    if not state.is_active() then
      util.notify("no workspace open")
      return
    end
    local tasks = state.current.tasks or {}
    if #tasks == 0 then
      util.notify("no tasks defined")
      return
    end
    local lines = { "Tasks:" }
    for _, t in ipairs(tasks) do
      local parts = { "  " .. t.name }
      if t.folder then
        table.insert(parts, " [" .. t.folder .. "]")
      end
      table.insert(parts, " → " .. t.cmd)
      table.insert(lines, table.concat(parts))
    end
    vim.api.nvim_echo(vim.tbl_map(function(l)
      return { l .. "\n" }
    end, lines), false, {})
  end, { desc = "List workspace tasks" })

  vim.api.nvim_create_user_command("WorkspaceTermList", function()
    if not state.is_active() then
      util.notify("no workspace open")
      return
    end
    local terms = state.current.terminals or {}
    if #terms == 0 then
      util.notify("no named terminals defined")
      return
    end
    local lines = { "Named terminals:" }
    for _, t in ipairs(terms) do
      local parts = { "  " .. t.name }
      if t.folder then
        table.insert(parts, " [" .. t.folder .. "]")
      end
      if t.cmd then
        table.insert(parts, " → " .. t.cmd)
      end
      if t.autostart then
        table.insert(parts, " (autostart)")
      end
      table.insert(lines, table.concat(parts))
    end
    vim.api.nvim_echo(vim.tbl_map(function(l)
      return { l .. "\n" }
    end, lines), false, {})
  end, { desc = "List named terminals in the current workspace" })

  vim.api.nvim_create_user_command("WorkspaceLoadSession", function()
    if not state.is_active() then
      util.notify("no workspace open", vim.log.levels.WARN)
      return
    end
    if require("multiroot.session").load(state.current.name) then
      util.notify("session loaded")
    else
      util.notify("no session for " .. state.current.name)
    end
  end, { desc = "Restore the current workspace session" })
end

return M
