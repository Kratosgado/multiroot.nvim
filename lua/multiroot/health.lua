local M = {}

local health = vim.health or require("health")
local start = health.start or health.report_start
local ok = health.ok or health.report_ok
local warn = health.warn or health.report_warn
local info = health.info or health.report_info
local error_ = health.error or health.report_error

function M.check()
  start("multiroot.nvim")

  if vim.fn.has("nvim-0.9") == 0 then
    error_("Requires Neovim 0.9+")
  else
    ok("Neovim version supported")
  end

  local state = require("multiroot.state")
  if state.is_active() then
    ok("Workspace active: " .. state.current.name)
    ok("Workspace file: " .. state.current.file)
    for _, f in ipairs(state.current.folders) do
      if vim.fn.isdirectory(f) == 1 then
        ok("  folder exists: " .. f)
      else
        warn("  folder missing: " .. f)
      end
    end
  else
    info("No workspace open")
  end

  local snacks = pcall(require, "snacks")
  local fzf = pcall(require, "fzf-lua")
  if snacks then
    ok("snacks.nvim: found")
  end
  if fzf then
    ok("fzf-lua: found")
  end
  if not snacks and not fzf then
    warn("No supported picker (snacks.nvim or fzf-lua) — files/grep commands will not work")
  end

  local config = require("multiroot.config").get()
  if vim.fn.isdirectory(config.data_dir) == 1 then
    ok("Data dir: " .. config.data_dir)
  else
    warn("Data dir missing (will be created on setup): " .. config.data_dir)
  end
end

return M
