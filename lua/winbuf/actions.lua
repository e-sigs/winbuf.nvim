-- Buffer actions: close, move, cycle

local M = {}
local api = vim.api

local function delete_buf(buf, force)
  local custom = require("winbuf").config.buf_delete
  if custom then
    custom(buf)
  else
    pcall(api.nvim_buf_delete, buf, { force = force or false })
  end
end

-- After closing a tab, pick the next one to the right. If there's nothing to
-- the right, fall back to the closest one to the left. Matches VS Code / browser behavior.
local function nearest_neighbor(bufs, buf)
  local remaining = {}
  local closed_at = 1

  for i, b in ipairs(bufs) do
    if b == buf then
      closed_at = i
    elseif api.nvim_buf_is_valid(b) and vim.bo[b].buflisted then
      table.insert(remaining, { buf = b, idx = i })
    end
  end

  if #remaining == 0 then return nil end

  for _, entry in ipairs(remaining) do
    if entry.idx > closed_at then return entry.buf end
  end
  return remaining[#remaining].buf
end

-- Check if a window is a "normal" editable window (not floating, not special buftype)
local function is_normal_win(win)
  if not api.nvim_win_is_valid(win) then return false end
  -- Skip floating windows
  local cfg = api.nvim_win_get_config(win)
  if cfg.relative and cfg.relative ~= "" then return false end
  -- Skip windows with special buftype (noice, terminal, quickfix, etc.)
  local buf = api.nvim_win_get_buf(win)
  local bt = vim.bo[buf].buftype
  if bt ~= "" then return false end
  return true
end

-- wincmd can jump diagonally (e.g. in a|b layout, wincmd j lands on b).
-- This checks the target is geometrically where we actually want it.
local function is_in_direction(src, tgt, dir)
  local sp = api.nvim_win_get_position(src)
  local tp = api.nvim_win_get_position(tgt)
  local sh = api.nvim_win_get_height(src)
  local sw = api.nvim_win_get_width(src)
  local th = api.nvim_win_get_height(tgt)
  local tw = api.nvim_win_get_width(tgt)

  if dir == "j" then
    return tp[1] >= sp[1] + sh
      and tp[2] < sp[2] + sw and tp[2] + tw > sp[2]
  elseif dir == "k" then
    return tp[1] + th <= sp[1]
      and tp[2] < sp[2] + sw and tp[2] + tw > sp[2]
  elseif dir == "l" then
    return tp[2] >= sp[2] + sw
      and tp[1] < sp[1] + sh and tp[1] + th > sp[1]
  elseif dir == "h" then
    return tp[2] + tw <= sp[2]
      and tp[1] < sp[1] + sh and tp[1] + th > sp[1]
  end
  return false
end

function M.close_buf(buf, force)
  local tracker = require("winbuf.tracker")
  buf = buf or api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(buf) then return end

  local win = api.nvim_get_current_win()
  local win_bufs = tracker.get_win_bufs(win)

  tracker._suppress_tracking = true

  tracker.remove_buf_from_win(win, buf)

  if api.nvim_win_get_buf(win) == buf then
    local next_buf = nearest_neighbor(win_bufs, buf)
    if next_buf then
      api.nvim_win_set_buf(win, next_buf)
    elseif #api.nvim_list_wins() > 1 then
      vim.cmd("close")
    else
      vim.cmd("enew")
    end
  end

  tracker._suppress_tracking = false

  if api.nvim_buf_is_valid(buf) and not tracker.is_buf_in_any_win(buf) then
    delete_buf(buf, force)
  end

  require("winbuf.render").refresh_all()
end

function M.close_split(force)
  local tracker = require("winbuf.tracker")
  local win = api.nvim_get_current_win()
  local win_bufs = tracker.get_win_bufs(win)

  if #api.nvim_list_wins() <= 1 then return end

  tracker._suppress_tracking = true
  vim.cmd("close")
  tracker._suppress_tracking = false

  -- Clean up orphans
  for _, buf in ipairs(win_bufs) do
    if api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      if not tracker.is_buf_in_any_win(buf) then
        delete_buf(buf, force)
      end
    end
  end

  require("winbuf.render").refresh_all()
end

function M.move_buf(direction)
  local tracker = require("winbuf.tracker")
  local buf = api.nvim_get_current_buf()
  local src_win = api.nvim_get_current_win()

  if vim.bo[buf].buftype ~= "" or not vim.bo[buf].buflisted then return end

  tracker._suppress_tracking = true

  -- See where wincmd takes us
  vim.cmd("wincmd " .. direction)
  local tgt_win = api.nvim_get_current_win()

  -- If wincmd went nowhere, went somewhere wrong, or landed on a special window, make a new split
  local need_split = tgt_win == src_win
    or not is_in_direction(src_win, tgt_win, direction)
    or not is_normal_win(tgt_win)

  if need_split then
    if tgt_win ~= src_win then api.nvim_set_current_win(src_win) end

    local split_cmds = {
      l = "rightbelow vsplit", h = "leftabove vsplit",
      j = "rightbelow split",  k = "leftabove split",
    }
    vim.cmd(split_cmds[direction])
    tgt_win = api.nvim_get_current_win()
  end

  -- Back to source — swap buffers
  api.nvim_set_current_win(src_win)

  local win_bufs = tracker.get_win_bufs(src_win)
  local next_buf = nearest_neighbor(win_bufs, buf)

  if next_buf then
    api.nvim_win_set_buf(src_win, next_buf)
  elseif #api.nvim_list_wins() > 1 then
    vim.cmd("close")
  end

  tracker.remove_buf_from_win(src_win, buf)

  api.nvim_set_current_win(tgt_win)
  api.nvim_win_set_buf(tgt_win, buf)
  tracker.add_buf_to_win(tgt_win, buf)

  tracker._suppress_tracking = false

  require("winbuf.render").refresh_all()
end

function M.cycle(offset)
  local tracker = require("winbuf.tracker")
  local win = api.nvim_get_current_win()
  local cur = api.nvim_get_current_buf()
  local bufs = tracker.get_win_bufs(win)

  bufs = vim.tbl_filter(function(b)
    return api.nvim_buf_is_valid(b) and vim.bo[b].buflisted
  end, bufs)

  if #bufs < 2 then return end

  local idx = 1
  for i, b in ipairs(bufs) do
    if b == cur then idx = i; break end
  end

  api.nvim_set_current_buf(bufs[((idx - 1 + offset) % #bufs) + 1])
end

return M
