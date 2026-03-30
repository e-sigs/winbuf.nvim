-- winbuf.nvim - Buffer tracking per window
-- Maintains a list of buffers associated with each window using window-local variables

local M = {}
local api = vim.api

--- Guard flag to suppress tracking during multi-step operations (move, close_split)
--- When true, BufEnter/WinEnter autocmds will not add buffers to windows
M._suppress_tracking = false

--- Get the buffer list for a window
--- @param win number
--- @return number[]
function M.get_win_bufs(win)
  if not api.nvim_win_is_valid(win) then
    return {}
  end
  local ok, bufs = pcall(api.nvim_win_get_var, win, "winbuf_bufs")
  if ok and type(bufs) == "table" then
    return vim.tbl_filter(function(b)
      return api.nvim_buf_is_valid(b) and vim.bo[b].buflisted
    end, bufs)
  end
  return {}
end

--- Save the buffer list for a window
--- @param win number
--- @param bufs number[]
function M.set_win_bufs(win, bufs)
  if api.nvim_win_is_valid(win) then
    api.nvim_win_set_var(win, "winbuf_bufs", bufs)
  end
end

--- Add a buffer to a window's list (if not already present)
--- @param win number
--- @param buf number
function M.add_buf_to_win(win, buf)
  if not api.nvim_win_is_valid(win) then
    return
  end
  if not api.nvim_buf_is_valid(buf) or not vim.bo[buf].buflisted then
    return
  end
  if vim.bo[buf].buftype ~= "" then
    return
  end

  local bufs = M.get_win_bufs(win)
  for _, b in ipairs(bufs) do
    if b == buf then
      return
    end
  end
  table.insert(bufs, buf)
  M.set_win_bufs(win, bufs)
end

--- Remove a buffer from a window's list
--- @param win number
--- @param buf number
function M.remove_buf_from_win(win, buf)
  if not api.nvim_win_is_valid(win) then
    return
  end
  local bufs = M.get_win_bufs(win)
  local new_bufs = vim.tbl_filter(function(b)
    return b ~= buf
  end, bufs)
  M.set_win_bufs(win, new_bufs)
end

--- Remove a buffer from all windows
--- @param buf number
function M.remove_buf_from_all(buf)
  for _, win in ipairs(api.nvim_list_wins()) do
    M.remove_buf_from_win(win, buf)
  end
end

--- Check if a buffer is tracked in any window (optionally excluding one)
--- @param buf number
--- @param exclude_win? number
--- @return boolean
function M.is_buf_in_any_win(buf, exclude_win)
  for _, w in ipairs(api.nvim_list_wins()) do
    if w ~= exclude_win then
      local wbufs = M.get_win_bufs(w)
      for _, b in ipairs(wbufs) do
        if b == buf then
          return true
        end
      end
    end
  end
  return false
end

--- Initialize buffer tracking autocmds
function M.setup()
  local group = api.nvim_create_augroup("WinBufTracker", { clear = true })

  api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function()
      if M._suppress_tracking then
        return
      end
      local win = api.nvim_get_current_win()
      local buf = api.nvim_get_current_buf()
      M.add_buf_to_win(win, buf)
      require("winbuf.render").refresh_all()
    end,
  })

  api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      if M._suppress_tracking then
        return
      end
      local win = api.nvim_get_current_win()
      local buf = api.nvim_get_current_buf()
      M.add_buf_to_win(win, buf)
      require("winbuf.render").refresh_all()
    end,
  })

  api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(ev)
      M.remove_buf_from_all(ev.buf)
      -- Prune click handler cache for deleted buffer
      require("winbuf.render").prune_click_cache(ev.buf)
      vim.schedule(function()
        require("winbuf.render").refresh_all()
      end)
    end,
  })

  api.nvim_create_autocmd("BufModifiedSet", {
    group = group,
    callback = function()
      require("winbuf.render").refresh_all()
    end,
  })

  -- Refresh winbar when diagnostics change (for diagnostic badges)
  api.nvim_create_autocmd("DiagnosticChanged", {
    group = group,
    callback = function()
      if require("winbuf").config.diagnostics then
        require("winbuf.render").refresh_all()
      end
    end,
  })

  -- Track buffers in existing windows on setup
  for _, win in ipairs(api.nvim_list_wins()) do
    local buf = api.nvim_win_get_buf(win)
    M.add_buf_to_win(win, buf)
  end
end

return M
