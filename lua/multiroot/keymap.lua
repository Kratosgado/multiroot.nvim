local config = require("multiroot.config")

local M = {}

local active = {}

local function normalize(spec)
  if type(spec) ~= "table" then
    return nil
  end
  local lhs = spec[1] or spec.lhs
  local rhs = spec[2] or spec.rhs
  if not lhs or not rhs then
    return nil
  end
  local opts = {}
  for k, v in pairs(spec) do
    if k ~= 1 and k ~= 2 and k ~= "lhs" and k ~= "rhs" and k ~= "mode" then
      opts[k] = v
    end
  end
  if opts.desc == nil then
    opts.desc = "Workspace"
  end
  return {
    mode = spec.mode or "n",
    lhs = lhs,
    rhs = rhs,
    opts = opts,
  }
end

function M.apply()
  M.clear()
  local state = require("multiroot.state")

  for _, spec in ipairs(config.get().keys_when_active or {}) do
    local km = normalize(spec)
    if km then
      pcall(vim.keymap.set, km.mode, km.lhs, km.rhs, km.opts)
      table.insert(active, { mode = km.mode, lhs = km.lhs })
    end
  end

  local ws_cfg = config.get().workspace_keymaps or {}
  if ws_cfg.enabled ~= false and state.is_active() then
    for _, spec in ipairs(state.current.keymaps or {}) do
      local km = normalize(spec)
      if km then
        km.opts.desc = km.opts.desc or ("Workspace: " .. km.lhs)
        pcall(vim.keymap.set, km.mode, km.lhs, km.rhs, km.opts)
        table.insert(active, { mode = km.mode, lhs = km.lhs })
      end
    end
  end
end

function M.clear()
  for _, km in ipairs(active) do
    pcall(vim.keymap.del, km.mode, km.lhs)
  end
  active = {}
end

function M.setup()
  local group = vim.api.nvim_create_augroup("MultirootKeys", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "MultirootLoaded",
    callback = function()
      M.apply()
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "MultirootClosed",
    callback = function()
      M.clear()
    end,
  })
end

return M
