-- Per-window buffer tracking via window-local variables (vim.w)

local M = {}
local api = vim.api

-- Guards multi-step operations (move, close_split) so BufEnter/WinEnter
-- don't re-add buffers mid-operation
M._suppress_tracking = false

-- Coalesce multiple refresh calls in the same event loop tick
local refresh_pending = false
local function schedule_refresh()
  if refresh_pending then return end
  refresh_pending = true
  vim.schedule(function()
    refresh_pending = false
    require("winbuf.render").refresh_all()
  end)
end

function M.get_win_bufs(win)
  if not api.nvim_win_is_valid(win) then return {} end
  local ok, bufs = pcall(api.nvim_win_get_var, win, "winbuf_bufs")
  if ok and type(bufs) == "table" then
    return bufs
  end
  return {}
end

function M.set_win_bufs(win, bufs)
  if api.nvim_win_is_valid(win) then
    api.nvim_win_set_var(win, "winbuf_bufs", bufs)
  end
end

function M.add_buf_to_win(win, buf)
  if not api.nvim_win_is_valid(win) then return end
  if not api.nvim_buf_is_valid(buf) then return end
  if not vim.bo[buf].buflisted or vim.bo[buf].buftype ~= "" then return end

  local bufs = M.get_win_bufs(win)
  for _, b in ipairs(bufs) do
    if b == buf then return end
  end
  table.insert(bufs, buf)
  M.set_win_bufs(win, bufs)
end

function M.remove_buf_from_win(win, buf)
  if not api.nvim_win_is_valid(win) then return end
  local bufs = M.get_win_bufs(win)
  local filtered = vim.tbl_filter(function(b) return b ~= buf end, bufs)
  M.set_win_bufs(win, filtered)
end

function M.remove_buf_from_all(buf)
  for _, win in ipairs(api.nvim_list_wins()) do
    M.remove_buf_from_win(win, buf)
  end
end

function M.is_buf_in_any_win(buf, exclude_win)
  for _, w in ipairs(api.nvim_list_wins()) do
    if w ~= exclude_win then
      for _, b in ipairs(M.get_win_bufs(w)) do
        if b == buf then return true end
      end
    end
  end
  return false
end

function M.setup()
  local group = api.nvim_create_augroup("WinBufTracker", { clear = true })

  api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function()
      if M._suppress_tracking then return end
      M.add_buf_to_win(api.nvim_get_current_win(), api.nvim_get_current_buf())
      schedule_refresh()
    end,
  })

  api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = function()
      if M._suppress_tracking then return end
      M.add_buf_to_win(api.nvim_get_current_win(), api.nvim_get_current_buf())
      schedule_refresh()
    end,
  })

  api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(ev)
      M.remove_buf_from_all(ev.buf)
      require("winbuf.render").prune_click_cache(ev.buf)
      schedule_refresh()
    end,
  })

  api.nvim_create_autocmd("BufModifiedSet", {
    group = group,
    callback = schedule_refresh,
  })

  api.nvim_create_autocmd("DiagnosticChanged", {
    group = group,
    callback = function()
      if require("winbuf").config.diagnostics then
        schedule_refresh()
      end
    end,
  })

  -- Pick up buffers already open when plugin loads
  for _, win in ipairs(api.nvim_list_wins()) do
    M.add_buf_to_win(win, api.nvim_win_get_buf(win))
  end
end

return M
