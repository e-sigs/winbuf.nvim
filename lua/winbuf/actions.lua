-- winbuf.nvim - Buffer actions (close, move, cycle)

local M = {}
local api = vim.api

--- Delete a buffer using custom or fallback method
--- @param buf number
local function delete_buf(buf)
  local config = require("winbuf").config
  if config.buf_delete then
    config.buf_delete(buf)
  else
    pcall(api.nvim_buf_delete, buf, { force = false })
  end
end

--- Close a buffer from the current window only.
--- Removes from window tracking. Deletes buffer entirely if no other window has it.
--- @param buf? number Buffer to close (defaults to current)
function M.close_buf(buf)
  local tracker = require("winbuf.tracker")
  buf = buf or api.nvim_get_current_buf()

  if not api.nvim_buf_is_valid(buf) then
    return
  end

  local win = api.nvim_get_current_win()
  local win_bufs = tracker.get_win_bufs(win)

  -- Remove buffer from this window's tracking
  tracker.remove_buf_from_win(win, buf)

  -- If this buffer is currently displayed, switch to another
  if api.nvim_win_get_buf(win) == buf then
    local remaining = vim.tbl_filter(function(b)
      return b ~= buf and api.nvim_buf_is_valid(b) and vim.bo[b].buflisted
    end, win_bufs)

    if #remaining > 0 then
      api.nvim_win_set_buf(win, remaining[#remaining])
    else
      if #api.nvim_list_wins() > 1 then
        vim.cmd("close")
      else
        vim.cmd("enew")
      end
    end
  end

  -- Only fully delete if no other window is tracking this buffer
  if not tracker.is_buf_in_any_win(buf, win) then
    delete_buf(buf)
  end

  require("winbuf.render").refresh_all()
end

--- Close the current split and delete any buffers not tracked in other windows.
function M.close_split()
  local tracker = require("winbuf.tracker")
  local win = api.nvim_get_current_win()
  local win_bufs = tracker.get_win_bufs(win)

  if #api.nvim_list_wins() <= 1 then
    return
  end

  vim.cmd("close")

  -- Delete orphaned buffers
  for _, buf in ipairs(win_bufs) do
    if api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      if not tracker.is_buf_in_any_win(buf) then
        delete_buf(buf)
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

  -- Try to move to the target direction
  vim.cmd("wincmd " .. direction)
  local target_win = api.nvim_get_current_win()

  if target_win == cur_win then
    -- No split in that direction — create one
    if direction == "l" or direction == "h" then
      vim.cmd("vsplit")
    else
      vim.cmd("split")
    end
    if direction == "h" or direction == "k" then
      vim.cmd("wincmd " .. direction:upper())
    end
    target_win = api.nvim_get_current_win()
  end

  -- Go back to the original window
  api.nvim_set_current_win(cur_win)

  -- Find another buffer in the source window to switch to
  local win_bufs = tracker.get_win_bufs(cur_win)
  local remaining = vim.tbl_filter(function(b)
    return api.nvim_buf_is_valid(b) and vim.bo[b].buflisted and b ~= buf
  end, win_bufs)

  if #remaining > 0 then
    api.nvim_win_set_buf(cur_win, remaining[#remaining])
  else
    vim.cmd("close")
  end

  -- Remove the buffer from the source window's tracking
  tracker.remove_buf_from_win(cur_win, buf)

  -- Set the buffer in the target window
  api.nvim_set_current_win(target_win)
  api.nvim_win_set_buf(target_win, buf)

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
