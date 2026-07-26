local M = {}

M.current = nil

function M.is_active()
  return M.current ~= nil
end

function M.folders()
  return M.current and M.current.folders or {}
end

function M.set(ws)
  M.current = ws
end

function M.clear()
  M.current = nil
end

return M
