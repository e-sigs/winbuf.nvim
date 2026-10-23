-- Group operations resolve decisions before changing membership or windows.
local M = {}
local api = vim.api
local T = require("winbuf.tracker")

local function safe_buffer(buf)
  local policy = vim.bo[buf].bufhidden
  if policy ~= "" and policy ~= "hide" then
    error("winbuf: cannot hide a buffer with bufhidden=" .. policy)
  end
end

local function can_switch(win, buf)
  if vim.wo[win].winfixbuf and api.nvim_win_get_buf(win) ~= buf then
    error("winbuf: window has winfixbuf")
  end
  safe_buffer(api.nvim_win_get_buf(win))
end

local function needs_save(buf)
  return vim.bo[buf].modified or (api.nvim_buf_get_name(buf) == "" and not T.empty(buf))
end

-- Synchronous decision contract: a resolver returns save/discard/cancel.
-- Deletion callbacks with ambiguous nil/async completion are not supported.
local function resolve(buf, force)
  if not needs_save(buf) then
    return "clean"
  end
  if force then
    return "discard"
  end -- only an explicit bang/API force
  local resolver = require("winbuf").config.resolve_modified
  local choice = resolver and resolver(buf) or nil
  if not resolver then
    local label = api.nvim_buf_get_name(buf)
    if label == "" then
      label = "[No Name]"
    end
    local answer = vim.fn.confirm("Close " .. label .. "?", "&Save\n&Discard\n&Cancel", 3)
    choice = ({ "save", "discard", "cancel" })[answer]
  end
  if choice ~= "save" and choice ~= "discard" then
    return "cancel"
  end
  if choice == "save" then
    local name = api.nvim_buf_get_name(buf)
    local command = "silent write"
    if name == "" then
      local path = vim.fn.input("Save as: ", "", "file")
      if path == "" then
        return "cancel"
      end
      command = "silent write " .. vim.fn.fnameescape(vim.fn.expand(path))
    end
    local ok, err = pcall(api.nvim_buf_call, buf, function()
      vim.cmd(command)
    end)
    if not ok or vim.bo[buf].modified then
      if name == "" and api.nvim_buf_get_name(buf) ~= "" then
        pcall(api.nvim_buf_set_name, buf, "")
      end
      vim.notify(tostring(err or "Buffer is still modified"), vim.log.levels.WARN)
      return "cancel"
    end
  end
  return choice
end

local function neighbor(bufs, buf)
  local idx = 1
  for i, b in ipairs(bufs) do
    if b == buf then
      idx = i
      break
    end
  end
  return bufs[idx + 1] or bufs[idx - 1]
end

local function other_window(win)
  for _, w in ipairs(T.windows(api.nvim_win_get_tabpage(win))) do
    if w ~= win then
      return w
    end
  end
end

local function delete_orphan(buf, decision)
  if not api.nvim_buf_is_valid(buf) or T.is_buf_in_any_win(buf) then
    return
  end
  -- force is only used after an explicit Discard decision.
  api.nvim_buf_delete(buf, { force = decision == "discard" })
end

-- Optional win argument is also used by mouse callbacks; never infer click
-- ownership from the focused editor. keep_window is used by close-all/others.
function M.close_buf(buf, force, win, keep_window)
  win = win or api.nvim_get_current_win()
  if not T.eligible(win) then
    return false
  end
  buf = buf or api.nvim_win_get_buf(win)
  local bufs = T.get_win_bufs(win)
  if not vim.tbl_contains(bufs, buf) and api.nvim_win_get_buf(win) ~= buf then
    return false
  end
  return T.guard(function()
    local current, target = api.nvim_win_get_buf(win), neighbor(bufs, buf)
    local other = other_window(win)
    if T.empty(buf) and #bufs == 0 then
      if other and not keep_window then
        api.nvim_win_close(win, false)
        api.nvim_set_current_win(other)
      else
        vim.bo[buf].buflisted = false
        vim.b[buf].winbuf_workspace = true
      end
      return true
    end
    safe_buffer(buf)
    -- Preflight before prompts and mutations (including inactive-file closes).
    if current == buf then
      can_switch(win, target or -1)
    end
    local decision = "shared"
    if not T.is_buf_in_any_win(buf, win) then
      decision = resolve(buf, force)
      if decision == "cancel" then
        return false
      end
    end
    local replacement = target
    if current == buf then
      replacement = replacement or T.workspace()
    end
    local ok, err = pcall(function()
      if current == buf then
        api.nvim_win_set_buf(win, replacement)
      end
      T.remove_buf_from_win(win, buf)
      delete_orphan(buf, decision)
    end)
    if not ok then
      if api.nvim_buf_is_valid(current) then
        pcall(api.nvim_win_set_buf, win, current)
      end
      T.set_win_bufs(win, bufs)
      error(err)
    end
    if #T.get_win_bufs(win) == 0 and other and not keep_window then
      api.nvim_win_close(win, false)
      api.nvim_set_current_win(other)
    end
    return true
  end)
end

function M.close_split(force, win)
  win = win or api.nvim_get_current_win()
  if not T.eligible(win) then
    return false
  end
  return T.guard(function()
    local bufs, decisions = T.get_win_bufs(win), {}
    local current = api.nvim_win_get_buf(win)
    -- Programmatic edits may precede TextChanged. Protect the displayed file
    -- even if its tracking event has not run yet.
    if T.trackable(current) and not vim.tbl_contains(bufs, current) then
      bufs[#bufs + 1] = current
    end
    safe_buffer(current)
    if vim.wo[win].winfixbuf then
      error("winbuf: window has winfixbuf")
    end
    for _, buf in ipairs(bufs) do
      safe_buffer(buf)
      if not T.is_buf_in_any_win(buf, win) then
        decisions[buf] = resolve(buf, force)
        if decisions[buf] == "cancel" then
          return false
        end
      end
    end
    local other = other_window(win)
    -- Closing the window is the only fallible layout change. Do it before
    -- committing membership; native close failure leaves the group intact.
    if other then
      api.nvim_win_close(win, false)
      api.nvim_set_current_win(other)
    else
      api.nvim_win_set_buf(win, T.workspace())
      T.set_win_bufs(win, {})
    end
    for _, buf in ipairs(bufs) do
      if decisions[buf] then
        -- A cleanup failure must never lose tracking of a surviving buffer.
        local ok, err = pcall(delete_orphan, buf, decisions[buf])
        if not ok then
          local recovery = other or win
          T.add_buf_to_win(recovery, buf)
          vim.notify("winbuf: retained file after deletion failure: " .. tostring(err), vim.log.levels.WARN)
        end
      end
    end
    return true
  end)
end

function M.select(buf, win)
  win = win or api.nvim_get_current_win()
  if not T.eligible(win) or not vim.tbl_contains(T.get_win_bufs(win), buf) then
    return false
  end
  return T.guard(function()
    can_switch(win, buf)
    api.nvim_win_set_buf(win, buf)
    api.nvim_set_current_win(win)
    return true
  end)
end

function M.cycle(offset)
  local win = api.nvim_get_current_win()
  if not T.eligible(win) then
    return false
  end
  local bufs = T.get_win_bufs(win)
  if #bufs < 2 then
    return false
  end
  local idx = 1
  for i, buf in ipairs(bufs) do
    if buf == api.nvim_win_get_buf(win) then
      idx = i
    end
  end
  return M.select(bufs[((idx - 1 + offset) % #bufs) + 1], win)
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

function M.move_buf(direction)
  local src = api.nvim_get_current_win()
  if not T.eligible(src) then
    return false
  end
  local buf = api.nvim_win_get_buf(src)
  if not T.trackable(buf) then
    return false
  end
  local commands = { h = "leftabove vsplit", l = "rightbelow vsplit", j = "rightbelow split", k = "leftabove split" }
  if not commands[direction] then
    return false
  end
  return T.guard(function()
    local pos, dst, distance = api.nvim_win_get_position(src), nil, math.huge
    local axis = (direction == "h" or direction == "l") and 2 or 1
    local sign = (direction == "h" or direction == "k") and -1 or 1
    for _, win in ipairs(T.windows()) do
      local p = api.nvim_win_get_position(win)
      local delta = (p[axis] - pos[axis]) * sign
      local score = delta * 10000 + math.abs(p[3 - axis] - pos[3 - axis])
      if delta > 0 and is_in_direction(src, win, direction) and score < distance then
        dst, distance = win, score
      end
    end
    local source_bufs = T.get_win_bufs(src)
    local replacement = neighbor(source_bufs, buf)
    can_switch(src, replacement or -1)
    if dst then
      can_switch(dst, buf)
    end
    local created, previous, target_bufs = false, nil, {}
    local ok, err = pcall(function()
      if not dst then
        vim.cmd(commands[direction])
        dst = api.nvim_get_current_win()
        created = true
        T.set_win_bufs(dst, {})
      end
      previous, target_bufs = api.nvim_win_get_buf(dst), T.get_win_bufs(dst)
      api.nvim_win_set_buf(dst, buf)
      api.nvim_win_set_buf(src, replacement or T.workspace())
      T.add_buf_to_win(dst, buf)
      T.remove_buf_from_win(src, buf)
      -- An empty source group closes after the transfer, not before it.
      if not replacement then
        api.nvim_win_close(src, false)
      end
      api.nvim_set_current_win(dst)
    end)
    if not ok then
      if api.nvim_win_is_valid(src) then
        pcall(api.nvim_win_set_buf, src, buf)
        T.set_win_bufs(src, source_bufs)
      end
      if dst and api.nvim_win_is_valid(dst) then
        if created then
          pcall(api.nvim_win_close, dst, false)
        elseif previous then
          pcall(api.nvim_win_set_buf, dst, previous)
          T.set_win_bufs(dst, target_bufs)
        end
      end
      error(err)
    end
    return true
  end)
end
return M
