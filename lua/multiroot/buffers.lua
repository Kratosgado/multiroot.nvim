local M = {}

local function normalize(p)
  if not p or p == "" then
    return nil
  end
  local abs = vim.fn.fnamemodify(p, ":p")
  return (abs:gsub("/$", ""))
end

local function under(path, folder)
  if not path or not folder then
    return false
  end
  local prefix = folder:sub(-1) == "/" and folder or folder .. "/"
  return path == folder or path:sub(1, #prefix) == prefix
end

function M.wipe_folders(folders)
  local roots = {}
  for _, f in ipairs(folders) do
    local n = normalize(f)
    if n then
      table.insert(roots, n)
    end
  end
  if #roots == 0 then
    return 0
  end
  local wiped = 0
  local skipped_modified = 0
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name and name ~= "" then
        local path = normalize(name)
        local match = false
        for _, root in ipairs(roots) do
          if under(path, root) then
            match = true
            break
          end
        end
        if match then
          if vim.bo[bufnr].modified then
            skipped_modified = skipped_modified + 1
          else
            pcall(vim.api.nvim_buf_delete, bufnr, { force = false })
            wiped = wiped + 1
          end
        end
      end
    end
  end
  return wiped, skipped_modified
end

return M
