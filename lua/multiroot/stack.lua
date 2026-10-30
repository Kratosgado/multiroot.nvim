local state = require("multiroot.state")
local util = require("multiroot.util")

local M = {}

-- Resolve a task spec's working directory against workspace folders
local function resolve_folder(folder, ws_folders)
  if not folder or folder == "" then
    return ws_folders[1] or vim.fn.getcwd()
  end
  local expanded = util.expand(folder)
  if vim.fn.isdirectory(expanded) == 1 then
    return expanded
  end
  for _, f in ipairs(ws_folders) do
    if vim.fn.fnamemodify(f, ":t") == folder then
      return f
    end
  end
  return expanded
end

-- Open a terminal for `spec` in the current window (no split created here).
-- Caller is responsible for positioning the cursor in the right window first.
local function open_in_win(spec, ws_folders)
  local cwd = resolve_folder(spec.folder, ws_folders)
  local env = require("multiroot.env").resolve(spec.env)
  local job_opts = { cwd = cwd }
  if env then
    job_opts.env = env
  end
  vim.fn.termopen(util.shell_cmd(spec.cmd), job_opts)
  local bufnr = vim.api.nvim_get_current_buf()
  vim.b[bufnr].multiroot_task = spec.name
  -- Rename buffer; ignore if name is already taken
  pcall(vim.api.nvim_buf_set_name, bufnr, "task: " .. spec.name)
  return bufnr
end

-- layout: "tabs" ─ one tab per task, navigate with gt/gT
local function run_tabs(specs, folders)
  for _, spec in ipairs(specs) do
    vim.cmd("tabnew")
    open_in_win(spec, folders)
  end
  vim.cmd("tabfirst")
end

-- layout: "columns" ─ all tasks side-by-side in one tab
local function run_columns(specs, folders)
  local n = #specs
  if n == 0 then return end
  vim.cmd("tabnew")
  open_in_win(specs[1], folders)
  for i = 2, n do
    -- belowright vsplit always opens to the right regardless of 'splitright'
    vim.cmd("belowright vsplit")
    vim.cmd("enew")
    open_in_win(specs[i], folders)
  end
  vim.cmd("wincmd t") -- focus leftmost window
end

-- layout: "grid" ─ tasks in pairs per tab (2-column grid, one "page" per row-pair)
-- e.g. 6 tasks →  tab1: [t1|t2]  tab2: [t3|t4]  tab3: [t5|t6]
local function run_grid(specs, folders)
  local n = #specs
  if n == 0 then return end
  local i = 1
  while i <= n do
    vim.cmd("tabnew")
    open_in_win(specs[i], folders)
    i = i + 1
    if i <= n then
      vim.cmd("belowright vsplit")
      vim.cmd("enew")
      open_in_win(specs[i], folders)
      i = i + 1
    end
  end
  vim.cmd("tabfirst")
end

-- Resolve task names in a stack to their full specs
local function resolve_task_specs(stack_spec, ws)
  local task_map = {}
  for _, t in ipairs(ws.tasks or {}) do
    task_map[t.name] = t
  end
  local resolved = {}
  for _, name in ipairs(stack_spec.tasks or {}) do
    local t = task_map[name]
    if t then
      table.insert(resolved, t)
    else
      util.notify("stack '" .. stack_spec.name .. "': task not found: " .. name, vim.log.levels.WARN)
    end
  end
  return resolved
end

function M.run(spec)
  local ws = state.current
  if not ws then
    util.notify("no workspace open", vim.log.levels.WARN)
    return
  end
  local task_specs = resolve_task_specs(spec, ws)
  if #task_specs == 0 then
    util.notify("stack '" .. spec.name .. "' has no runnable tasks", vim.log.levels.WARN)
    return
  end
  local layout = spec.layout or "tabs"
  if layout == "columns" then
    run_columns(task_specs, ws.folders)
  elseif layout == "grid" then
    run_grid(task_specs, ws.folders)
  else
    run_tabs(task_specs, ws.folders)
  end
  util.notify("stack '" .. spec.name .. "' started (" .. #task_specs .. " tasks, layout: " .. layout .. ")")
end

function M.run_named(name)
  local ws = state.current
  if not ws then
    util.notify("no workspace open", vim.log.levels.WARN)
    return
  end
  for _, s in ipairs(ws.stacks or {}) do
    if s.name == name then
      return M.run(s)
    end
  end
  util.notify("no stack named '" .. name .. "'", vim.log.levels.WARN)
end

function M.pick()
  local ws = state.current
  if not ws then
    util.notify("no workspace open", vim.log.levels.WARN)
    return
  end
  local stacks = ws.stacks or {}
  if #stacks == 0 then
    util.notify("workspace defines no stacks")
    return
  end
  vim.ui.select(stacks, {
    prompt = "Run stack:",
    format_item = function(s)
      local parts = { s.name }
      if s.description then
        table.insert(parts, "— " .. s.description)
      end
      table.insert(parts, " [" .. table.concat(s.tasks, ", ") .. "]")
      return table.concat(parts, " ")
    end,
  }, function(choice)
    if choice then
      M.run(choice)
    end
  end)
end

function M.list()
  if not state.is_active() then
    return {}
  end
  return state.current.stacks or {}
end

return M
