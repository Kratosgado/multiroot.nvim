local state = require("multiroot.state")
local util = require("multiroot.util")

local M = {}

local function resolve_folder(folder)
  if not folder or folder == "" then
    return state.folders()[1] or vim.fn.getcwd()
  end
  local expanded = util.expand(folder)
  if vim.fn.isdirectory(expanded) == 1 then
    return expanded
  end
  for _, f in ipairs(state.folders()) do
    if vim.fn.fnamemodify(f, ":t") == folder then
      return f
    end
  end
  return expanded
end

local function has_snacks_term()
  local ok = pcall(require, "snacks")
  return ok and _G.Snacks and _G.Snacks.terminal ~= nil
end

local function run(spec)
  local cwd = resolve_folder(spec.folder)
  local title = "task: " .. spec.name
  if has_snacks_term() then
    return _G.Snacks.terminal.open(spec.cmd, {
      cwd = cwd,
      win = { title = title, position = spec.position or "bottom" },
      interactive = spec.interactive == true,
    })
  end
  vim.cmd("botright split")
  local prev = vim.fn.getcwd()
  pcall(vim.cmd, "lcd " .. vim.fn.fnameescape(cwd))
  vim.fn.termopen({ vim.o.shell, "-c", spec.cmd })
  local bufnr = vim.api.nvim_get_current_buf()
  vim.b[bufnr].multiroot_task = spec.name
  pcall(vim.cmd, "lcd " .. vim.fn.fnameescape(prev))
  return bufnr
end

function M.run_named(name)
  if not state.is_active() then
    util.notify("no workspace open", vim.log.levels.WARN)
    return
  end
  local tasks = state.current.tasks or {}
  for _, t in ipairs(tasks) do
    if t.name == name then
      return run(t)
    end
  end
  util.notify("no task named '" .. name .. "'", vim.log.levels.WARN)
end

function M.pick()
  if not state.is_active() then
    util.notify("no workspace open", vim.log.levels.WARN)
    return
  end
  local tasks = state.current.tasks or {}
  if #tasks == 0 then
    util.notify("workspace defines no tasks")
    return
  end
  vim.ui.select(tasks, {
    prompt = "Run task:",
    format_item = function(item)
      local parts = { item.name }
      if item.folder then
        table.insert(parts, "[" .. item.folder .. "]")
      end
      table.insert(parts, "→ " .. (item.cmd or ""))
      return table.concat(parts, " ")
    end,
  }, function(choice)
    if choice then
      run(choice)
    end
  end)
end

function M.list()
  if not state.is_active() then
    return {}
  end
  return state.current.tasks or {}
end

return M
