-- Per-window ordered buffer membership. Window ownership prevents split copies
-- of vim.w variables from inheriting an unrelated group's inactive files.
local M = { _suppress_tracking = false }
local api = vim.api
local pending = false

function M.empty(buf)
  return api.nvim_buf_is_loaded(buf)
    and vim.bo[buf].buftype == ""
    and api.nvim_buf_get_name(buf) == ""
    and not vim.bo[buf].modified
    and api.nvim_buf_line_count(buf) == 1
    and api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
end

function M.eligible(win)
  if not api.nvim_win_is_valid(win) then
    return false
  end
  local buf = api.nvim_win_get_buf(win)
  if
    api.nvim_win_get_config(win).relative ~= ""
    or vim.wo[win].previewwindow
    or vim.wo[win].diff
    or vim.bo[buf].buftype ~= ""
    or vim.w[win].winbuf_exclude
    or vim.b[buf].winbuf_exclude
  then
    return false
  end
  local filter = require("winbuf").config.eligible
  return not filter or filter(win, buf) ~= false
end

function M.trackable(buf)
  return api.nvim_buf_is_valid(buf)
    and vim.bo[buf].buflisted
    and vim.bo[buf].buftype == ""
    and not vim.b[buf].winbuf_exclude
    and not M.empty(buf)
end

function M.windows(tab)
  return vim.tbl_filter(M.eligible, api.nvim_tabpage_list_wins(tab or 0))
end

function M.get_win_bufs(win)
  if not api.nvim_win_is_valid(win) or vim.w[win].winbuf_owner ~= win then
    return {}
  end
  return vim.tbl_filter(M.trackable, vim.w[win].winbuf_bufs or {})
end

function M.set_win_bufs(win, bufs)
  if not api.nvim_win_is_valid(win) then
    return
  end
  local result, seen = {}, {}
  for _, buf in ipairs(bufs) do
    if M.trackable(buf) and not seen[buf] then
      result[#result + 1], seen[buf] = buf, true
    end
  end
  vim.w[win].winbuf_owner, vim.w[win].winbuf_bufs = win, result
end

function M.add_buf_to_win(win, buf)
  if not M.eligible(win) or not M.trackable(buf) then
    return
  end
  local bufs = M.get_win_bufs(win)
  if not vim.tbl_contains(bufs, buf) then
    bufs[#bufs + 1] = buf
  end
  M.set_win_bufs(win, bufs)
end

function M.remove_buf_from_win(win, buf)
  M.set_win_bufs(
    win,
    vim.tbl_filter(function(b)
      return b ~= buf
    end, M.get_win_bufs(win))
  )
end

function M.remove_buf_from_all(buf)
  for _, win in ipairs(api.nvim_list_wins()) do
    M.remove_buf_from_win(win, buf)
  end
end

function M.is_buf_in_any_win(buf, exclude)
  for _, win in ipairs(api.nvim_list_wins()) do
    if
      win ~= exclude
      and (api.nvim_win_get_buf(win) == buf or (M.eligible(win) and vim.tbl_contains(M.get_win_bufs(win), buf)))
    then
      return true
    end
  end
  return false
end

function M.guard(fn)
  local previous = M._suppress_tracking
  M._suppress_tracking = true
  local ok, result = xpcall(fn, debug.traceback)
  M._suppress_tracking = previous
  M.refresh()
  if not ok then
    vim.notify(result, vim.log.levels.ERROR)
    return false
  end
  return result
end

function M.refresh()
  if pending then
    return
  end
  pending = true
  vim.schedule(function()
    pending = false
    for _, win in ipairs(api.nvim_list_wins()) do
      if not M.eligible(win) then
        M.set_win_bufs(win, {})
      elseif not M._suppress_tracking then
        M.add_buf_to_win(win, api.nvim_win_get_buf(win))
      end
    end
    require("winbuf.render").refresh_all()
  end)
end

function M.workspace()
  for _, buf in ipairs(api.nvim_list_bufs()) do
    if
      M.empty(buf)
      and #vim.fn.win_findbuf(buf) == 0
      and (vim.bo[buf].bufhidden == "" or vim.bo[buf].bufhidden == "hide")
    then
      vim.bo[buf].buflisted = false
      vim.b[buf].winbuf_workspace = true
      return buf
    end
  end
  local buf = api.nvim_create_buf(false, false)
  vim.b[buf].winbuf_workspace = true
  return buf
end

function M.setup()
  local group = api.nvim_create_augroup("WinBufTracker", { clear = true })
  api.nvim_create_autocmd(
    { "BufEnter", "WinEnter", "BufWinEnter", "TextChanged", "TextChangedI", "BufModifiedSet", "BufFilePost" },
    {
      group = group,
      callback = function(ev)
        if M._suppress_tracking then
          return
        end
        if api.nvim_buf_is_valid(ev.buf) and vim.b[ev.buf].winbuf_workspace and not M.empty(ev.buf) then
          vim.bo[ev.buf].buflisted = true
          vim.b[ev.buf].winbuf_workspace = nil
        end
        M.add_buf_to_win(api.nvim_get_current_win(), api.nvim_get_current_buf())
        M.refresh()
      end,
    }
  )
  api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    callback = function(ev)
      M.remove_buf_from_all(ev.buf)
      M.refresh()
    end,
  })
  api.nvim_create_autocmd({ "WinClosed", "WinResized", "FileType", "DiagnosticChanged" }, {
    group = group,
    callback = M.refresh,
  })
  api.nvim_create_autocmd(
    "OptionSet",
    { group = group, pattern = { "diff", "buftype", "buflisted" }, callback = M.refresh }
  )
  for _, win in ipairs(api.nvim_list_wins()) do
    M.add_buf_to_win(win, api.nvim_win_get_buf(win))
  end
  M.refresh()
end
return M
