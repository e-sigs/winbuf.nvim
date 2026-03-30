-- winbuf.nvim - Buffer actions (close, move, cycle)

local M = {}
local api = vim.api

--- Delete a buffer using custom or fallback method
--- @param buf number
--- @param force? boolean Force delete even if modified
local function delete_buf(buf, force)
  local config = require("winbuf").config
  if config.buf_delete then
    config.buf_delete(buf)
  else
    pcall(api.nvim_buf_delete, buf, { force = force or false })
  end
end

--- Find the nearest neighbor index in a buffer list after removing one
--- @param bufs number[] The full buffer list before removal
--- @param buf number The buffer being removed
--- @return number|nil The buffer to switch to, or nil if none
local function find_nearest_neighbor(bufs, buf)
  local remaining = {}
  local closed_idx = 1

  for i, b in ipairs(bufs) do
    if b == buf then
      closed_idx = i
    elseif api.nvim_buf_is_valid(b) and vim.bo[b].buflisted then
      table.insert(remaining, { buf = b, idx = i })
    end
  end

  if #remaining == 0 then
    return nil
  end

  -- Prefer the next buffer, fall back to previous
  for _, entry in ipairs(remaining) do
    if entry.idx > closed_idx then
      return entry.buf
    end
  end
  -- No buffer after closed_idx, use the last one before it
  return remaining[#remaining].buf
end

--- Close a buffer from the current window only.
--- Removes from window tracking. Deletes buffer entirely if no other window has it.
--- @param buf? number Buffer to close (defaults to current)
--- @param force? boolean Force close even if modified
function M.close_buf(buf, force)
  local tracker = require("winbuf.tracker")
  buf = buf or api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(buf) then
    return
  end

  local win = api.nvim_get_current_win()
  local win_bufs = tracker.get_win_bufs(win)

  -- Suppress tracking to prevent BufEnter from re-adding during switch
  tracker._suppress_tracking = true

  -- Remove buffer from this window's tracking
  tracker.remove_buf_from_win(win, buf)

  -- If this buffer is currently displayed, switch to nearest neighbor
  if api.nvim_win_get_buf(win) == buf then
    local neighbor = find_nearest_neighbor(win_bufs, buf)

    if neighbor then
      api.nvim_win_set_buf(win, neighbor)
    else
      if #api.nvim_list_wins() > 1 then
        vim.cmd("close")
      else
        vim.cmd("enew")
      end
    end
  end

  tracker._suppress_tracking = false

  -- Only fully delete if no other window is tracking this buffer
  if api.nvim_buf_is_valid(buf) and not tracker.is_buf_in_any_win(buf) then
    delete_buf(buf, force)
  end

  require("winbuf.render").refresh_all()
end

--- Close the current split and delete any buffers not tracked in other windows.
--- @param force? boolean Force delete orphaned modified buffers
function M.close_split(force)
  local tracker = require("winbuf.tracker")
  local win = api.nvim_get_current_win()
  local win_bufs = tracker.get_win_bufs(win)

  if #api.nvim_list_wins() <= 1 then
    return
  end

  -- Suppress tracking to prevent WinEnter/BufEnter from re-adding orphans
  tracker._suppress_tracking = true

  vim.cmd("close")

  tracker._suppress_tracking = false

  -- Delete orphaned buffers (not tracked in any remaining window)
  for _, buf in ipairs(win_bufs) do
    if api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      if not tracker.is_buf_in_any_win(buf) then
        delete_buf(buf, force)
      end
    end
  end

  require("winbuf.render").refresh_all()
end

--- Move the current buffer to an adjacent split (VS Code editor group style).
--- Creates a new split if none exists in that direction.
--- @param direction string One of "h", "j", "k", "l"
function M.move_buf(direction)
  local tracker = require("winbuf.tracker")
  local buf = api.nvim_get_current_buf()
  local cur_win = api.nvim_get_current_win()

  -- Only move normal file buffers
  if vim.bo[buf].buftype ~= "" or not vim.bo[buf].buflisted then
    return
  end

  -- Suppress tracking for the entire move operation
  tracker._suppress_tracking = true

  -- Try to move to the target direction
  vim.cmd("wincmd " .. direction)
  local target_win = api.nvim_get_current_win()

  if target_win == cur_win then
    -- No split in that direction — create one adjacent
    if direction == "l" then
      vim.cmd("rightbelow vsplit")
    elseif direction == "h" then
      vim.cmd("leftabove vsplit")
    elseif direction == "j" then
      vim.cmd("rightbelow split")
    elseif direction == "k" then
      vim.cmd("leftabove split")
    end
    target_win = api.nvim_get_current_win()
  end

  -- Go back to the original window
  api.nvim_set_current_win(cur_win)

  -- Find nearest neighbor buffer in the source window to switch to
  local win_bufs = tracker.get_win_bufs(cur_win)
  local neighbor = find_nearest_neighbor(win_bufs, buf)

  if neighbor then
    api.nvim_win_set_buf(cur_win, neighbor)
  else
    -- No other buffers — close the source split
    if #api.nvim_list_wins() > 1 then
      vim.cmd("close")
    end
  end

  -- Remove the buffer from the source window's tracking
  tracker.remove_buf_from_win(cur_win, buf)

  -- Set the buffer in the target window and add to tracking
  api.nvim_set_current_win(target_win)
  api.nvim_win_set_buf(target_win, buf)
  tracker.add_buf_to_win(target_win, buf)

  -- Re-enable tracking
  tracker._suppress_tracking = false

  require("winbuf.render").refresh_all()
end

--- Cycle through buffers in the current window's group.
--- @param offset number Positive for next, negative for previous
function M.cycle(offset)
  local tracker = require("winbuf.tracker")
  local win = api.nvim_get_current_win()
  local cur_buf = api.nvim_get_current_buf()
  local bufs = tracker.get_win_bufs(win)

  -- Filter to valid listed buffers
  bufs = vim.tbl_filter(function(b)
    return api.nvim_buf_is_valid(b) and vim.bo[b].buflisted
  end, bufs)

  if #bufs < 2 then
    return
  end

  local idx = 1
  for i, b in ipairs(bufs) do
    if b == cur_buf then
      idx = i
      break
    end
  end

  local new_idx = ((idx - 1 + offset) % #bufs) + 1
  api.nvim_set_current_buf(bufs[new_idx])
end

return M
