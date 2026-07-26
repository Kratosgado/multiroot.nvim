local config = require("multiroot.config")
local state = require("multiroot.state")
local util = require("multiroot.util")

local M = {}

-- registry: workspace_name -> { term_name -> bufnr }
local registry = {}

local function has_snacks()
  local ok = pcall(require, "snacks")
  return ok and _G.Snacks and _G.Snacks.terminal ~= nil
end

local function ws_registry()
  if not state.is_active() then
    return nil
  end
  local key = state.current.name
  registry[key] = registry[key] or {}
  return registry[key]
end

local function buf_alive(bufnr)
  return bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "terminal"
end

local function focus_term_buf(bufnr)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == bufnr then
      vim.api.nvim_set_current_win(win)
      vim.cmd("startinsert")
      return true
    end
  end
  vim.cmd("split")
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.cmd("startinsert")
  return true
end

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

local function open_snacks(opts)
  local sopts = {
    cwd = opts.cwd,
    win = { position = opts.position or "bottom" },
  }
  if opts.env then
    sopts.env = opts.env
  end
  local cmd = opts.cmd
  if cmd and cmd ~= "" then
    return _G.Snacks.terminal.open(cmd, sopts)
  end
  return _G.Snacks.terminal.open(nil, sopts)
end

local function open_builtin(opts)
  vim.cmd((opts.position == "float" and "split" or "botright split"))
  local prev = vim.fn.getcwd()
  local ok_cd = pcall(vim.cmd, "lcd " .. vim.fn.fnameescape(opts.cwd))
  local shell = vim.o.shell
  local job_opts = {}
  if opts.env then
    job_opts.env = opts.env
  end
  local cmd = opts.cmd
  if cmd and cmd ~= "" then
    vim.fn.termopen({ shell, "-c", cmd }, job_opts)
  else
    vim.fn.termopen(shell, job_opts)
  end
  local bufnr = vim.api.nvim_get_current_buf()
  if not ok_cd then
    pcall(vim.cmd, "lcd " .. vim.fn.fnameescape(prev))
  end
  vim.cmd("startinsert")
  return { buf = bufnr, win = vim.api.nvim_get_current_win() }
end

local function open_term(opts)
  if has_snacks() then
    return open_snacks(opts)
  end
  return open_builtin(opts)
end

function M.open_folder(folder, profile)
  if not state.is_active() then
    util.notify("no workspace open", vim.log.levels.WARN)
    return
  end
  local cwd = resolve_folder(folder)
  local env = require("multiroot.env").resolve(profile)
  return open_term({ cwd = cwd, env = env })
end

function M.run_named(name)
  if not state.is_active() then
    util.notify("no workspace open", vim.log.levels.WARN)
    return
  end
  local terms = state.current.terminals or {}
  local spec
  for _, t in ipairs(terms) do
    if t.name == name then
      spec = t
      break
    end
  end
  if not spec then
    util.notify("no terminal named '" .. name .. "'", vim.log.levels.WARN)
    return
  end
  local reg = ws_registry()
  local existing = reg[spec.name]
  if buf_alive(existing) then
    focus_term_buf(existing)
    return existing
  end
  local cwd = resolve_folder(spec.folder)
  local env = require("multiroot.env").resolve(spec.env)
  local term = open_term({ cwd = cwd, cmd = spec.cmd, position = spec.position, env = env })
  local bufnr
  if type(term) == "table" then
    bufnr = term.buf or (term.win and vim.api.nvim_win_get_buf(term.win))
  end
  if bufnr then
    reg[spec.name] = bufnr
  end
  return bufnr
end

function M.pick_folder()
  if not state.is_active() then
    util.notify("no workspace open", vim.log.levels.WARN)
    return
  end
  local folders = state.folders()
  if #folders == 1 then
    return M.open_folder(folders[1])
  end
  vim.ui.select(folders, {
    prompt = "Open terminal in folder:",
    format_item = function(item)
      return vim.fn.fnamemodify(item, ":t") .. "  (" .. item .. ")"
    end,
  }, function(choice)
    if choice then
      M.open_folder(choice)
    end
  end)
end

function M.pick_named()
  if not state.is_active() then
    util.notify("no workspace open", vim.log.levels.WARN)
    return
  end
  local terms = state.current.terminals or {}
  if #terms == 0 then
    util.notify("workspace defines no named terminals")
    return
  end
  vim.ui.select(terms, {
    prompt = "Run named terminal:",
    format_item = function(item)
      local parts = { item.name }
      if item.folder then
        table.insert(parts, "(" .. item.folder .. ")")
      end
      if item.cmd then
        table.insert(parts, "→ " .. item.cmd)
      end
      return table.concat(parts, " ")
    end,
  }, function(choice)
    if choice then
      M.run_named(choice.name)
    end
  end)
end

function M.close_all_for_current()
  if not state.is_active() then
    return
  end
  local reg = ws_registry()
  if not reg then
    return
  end
  for name, bufnr in pairs(reg) do
    if buf_alive(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
    reg[name] = nil
  end
end

function M.autostart()
  if not state.is_active() then
    return
  end
  local terms = state.current.terminals or {}
  for _, spec in ipairs(terms) do
    if spec.autostart then
      pcall(M.run_named, spec.name)
    end
  end
end

function M.list_named()
  if not state.is_active() then
    return {}
  end
  return state.current.terminals or {}
end

return M
