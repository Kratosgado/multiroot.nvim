local config = require("multiroot.config")
local state = require("multiroot.state")
local util = require("multiroot.util")

local M = {}

local TIMEOUT_EXIT_CODE = 124 -- what vim.system reports when it kills a command

local function label(hook)
  return hook.name or hook.cmd
end

local function enabled()
  if not config.get().hooks.enabled then
    return false
  end
  if not vim.system then
    util.notify("hooks need Neovim 0.10+ (vim.system)", vim.log.levels.WARN)
    return false
  end
  return true
end

local function list_for(ws, phase)
  return ws.hooks and ws.hooks[phase] or {}
end

local function spawn_opts(hook)
  return {
    cwd = util.resolve_folder(hook.folder),
    env = require("multiroot.env").resolve(hook.env),
    text = true,
    timeout = config.get().hooks.timeout,
  }
end

local function argv(hook)
  return { vim.o.shell, "-c", hook.cmd }
end

local function failure_message(phase, hook, res)
  local msg
  if res.code == TIMEOUT_EXIT_CODE then
    msg = ("%s hook '%s' timed out after %ds"):format(phase, label(hook), config.get().hooks.timeout / 1000)
  else
    msg = ("%s hook '%s' failed (exit %d)"):format(phase, label(hook), res.code)
  end
  local err = vim.trim(res.stderr or "")
  if err ~= "" then
    msg = msg .. ": " .. err:sub(1, 400)
  end
  return msg
end

local function summary(phase, total, failed)
  if failed == 0 then
    util.notify(("ran %d %s hook%s"):format(total, phase, total == 1 and "" or "s"))
  end
end

-- on_open: run in order without blocking startup. A failing hook is reported
-- and the rest still run; chain with `&&` inside one cmd to make steps depend
-- on each other. Stops quietly if the workspace was closed or switched meanwhile.
local function run_async(ws, hooks, phase)
  local failed = 0
  local function step(i)
    local hook = hooks[i]
    if not hook then
      return summary(phase, #hooks, failed)
    end
    if not state.current or state.current.file ~= ws.file then
      return
    end
    local function done(res)
      if res.code ~= 0 then
        failed = failed + 1
        util.notify(failure_message(phase, hook, res), vim.log.levels.WARN)
      end
      step(i + 1)
    end
    local ok, err = pcall(vim.system, argv(hook), spawn_opts(hook), vim.schedule_wrap(done))
    if not ok then
      done({ code = -1, stderr = tostring(err) })
    end
  end
  step(1)
end

-- on_close: must finish before the workspace is torn down (and before Neovim
-- exits), so run in order and wait.
local function run_sync(hooks, phase)
  local failed = 0
  for _, hook in ipairs(hooks) do
    local ok, res = pcall(function()
      return vim.system(argv(hook), spawn_opts(hook)):wait()
    end)
    if not ok then
      res = { code = -1, stderr = tostring(res) }
    end
    if res.code ~= 0 then
      failed = failed + 1
      util.notify(failure_message(phase, hook, res), vim.log.levels.WARN)
    end
  end
  summary(phase, #hooks, failed)
end

function M.run_open(ws)
  local hooks = list_for(ws, "on_open")
  if #hooks == 0 or not enabled() then
    return
  end
  run_async(ws, hooks, "on_open")
end

function M.run_close(ws)
  local hooks = list_for(ws, "on_close")
  if #hooks == 0 or not enabled() then
    return
  end
  run_sync(hooks, "on_close")
end

function M.setup()
  -- Quitting Neovim never goes through close(), so run on_close here.
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("MultirootHooks", { clear = true }),
    callback = function()
      if state.is_active() then
        M.run_close(state.current)
      end
    end,
  })
end

return M
