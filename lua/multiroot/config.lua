local M = {}

M.defaults = {
  workspace_file = ".nvim-workspace.json",
  data_dir = vim.fn.stdpath("data") .. "/multiroot",
  auto_load = true,
  session = {
    enabled = true,
    autosave = true,
    autoload = true,
  },
  lsp = {
    enabled = true,
  },
  picker = "auto",
  notify = true,
  keys_when_active = {},
  terminal = {
    autostart = true,
  },
  on_close = {
    wipe_buffers = true,   -- delete file buffers under the workspace folders
    close_terminals = true, -- delete named terminal buffers for the workspace
  },
  schema = {
    register = true,       -- auto-register workspace.json schema with jsonls
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
  vim.fn.mkdir(M.options.data_dir, "p")
  vim.fn.mkdir(M.options.data_dir .. "/sessions", "p")
end

function M.get()
  return M.options
end

return M
