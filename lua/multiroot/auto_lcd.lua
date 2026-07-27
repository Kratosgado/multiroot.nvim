local config = require("multiroot.config")
local state = require("multiroot.state")
local util = require("multiroot.util")

local M = {}

local group

function M.setup()
  if not config.get().on_buf_enter or not config.get().on_buf_enter.lcd then
    return
  end
  group = vim.api.nvim_create_augroup("MultirootAutoLcd", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(args)
      if not state.is_active() then
        return
      end
      if vim.bo[args.buf].buftype ~= "" then
        return
      end
      local folder = util.folder_for_buffer(args.buf)
      if not folder then
        return
      end
      if vim.fn.getcwd(0) == folder then
        return
      end
      pcall(vim.cmd, "lcd " .. vim.fn.fnameescape(folder))
    end,
  })
end

return M
