local config = require("multiroot.config")
local state = require("multiroot.state")
local util = require("multiroot.util")

local M = {}

local function has_snacks()
  local ok = pcall(require, "snacks")
  return ok and _G.Snacks and _G.Snacks.picker ~= nil
end

local function has_fzf()
  return pcall(require, "fzf-lua")
end

--- Which picker LazyVim registered ("snacks", "fzf", "telescope", or nil).
--- This is the source of truth in LazyVim setups regardless of what else is loaded.
local function lazyvim_picker_name()
  local ok, name = pcall(function()
    return _G.LazyVim
      and _G.LazyVim.pick
      and _G.LazyVim.pick.picker
      and _G.LazyVim.pick.picker.name
  end)
  return ok and name or nil
end

local function detect()
  local pref = config.get().picker
  if pref == "snacks" then
    return has_snacks() and "snacks" or nil
  end
  if pref == "fzf" then
    return has_fzf() and "fzf" or nil
  end
  local lv = lazyvim_picker_name()
  if lv == "snacks" and has_snacks() then
    return "snacks"
  end
  if lv == "fzf" and has_fzf() then
    return "fzf"
  end
  if has_fzf() then
    return "fzf"
  end
  if has_snacks() then
    return "snacks"
  end
  return nil
end

local function ensure_workspace()
  if not state.is_active() then
    util.notify("no workspace open", vim.log.levels.WARN)
    return false
  end
  if #state.folders() == 0 then
    util.notify("workspace has no folders", vim.log.levels.WARN)
    return false
  end
  return true
end

function M.files()
  if not ensure_workspace() then
    return
  end
  local folders = state.folders()
  local picker = detect()
  if picker == "snacks" then
    _G.Snacks.picker.files({ dirs = folders })
  elseif picker == "fzf" then
    require("fzf-lua").files({ search_paths = folders })
  else
    util.notify("no picker available (install snacks.nvim or fzf-lua)", vim.log.levels.ERROR)
  end
end

function M.grep()
  if not ensure_workspace() then
    return
  end
  local folders = state.folders()
  local picker = detect()
  if picker == "snacks" then
    _G.Snacks.picker.grep({ dirs = folders })
  elseif picker == "fzf" then
    require("fzf-lua").live_grep({ search_paths = folders })
  else
    util.notify("no picker available (install snacks.nvim or fzf-lua)", vim.log.levels.ERROR)
  end
end

function M.pick_recent()
  local recent = require("multiroot.recent").read()
  if #recent == 0 then
    util.notify("no recent workspaces")
    return
  end
  local picker = detect()
  if picker == "snacks" then
    local items = {}
    for i, entry in ipairs(recent) do
      table.insert(items, {
        idx = i,
        text = entry.name .. "  " .. entry.file,
        name = entry.name,
        file = entry.file,
        folders = entry.folders,
      })
    end
    _G.Snacks.picker({
      title = "Recent workspaces",
      items = items,
      format = "text",
      confirm = function(picker_, item)
        picker_:close()
        if item then
          require("multiroot").open(item.file)
        end
      end,
    })
  else
    vim.ui.select(recent, {
      prompt = "Recent workspaces:",
      format_item = function(item)
        return item.name .. "  (" .. item.file .. ")"
      end,
    }, function(choice)
      if choice then
        require("multiroot").open(choice.file)
      end
    end)
  end
end

return M
