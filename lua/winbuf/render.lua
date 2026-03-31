-- Winbar rendering engine

local M = {}
local api = vim.api
local winbuf = nil -- lazy-loaded below
local tracker = nil

local click_cache = {}

local function get_diagnostics(buf)
  if not api.nvim_buf_is_valid(buf) then
    return { error = 0, warning = 0 }
  end
  local counts = { error = 0, warning = 0 }
  for _, d in ipairs(vim.diagnostic.get(buf)) do
    if d.severity == vim.diagnostic.severity.ERROR then
      counts.error = counts.error + 1
    elseif d.severity == vim.diagnostic.severity.WARN then
      counts.warning = counts.warning + 1
    end
  end
  return counts
end

-- Multibyte-safe truncation
local function truncate(name, max_len)
  if not max_len or max_len <= 0 then return name end
  if vim.fn.strcharlen(name) <= max_len then return name end
  if max_len <= 1 then return vim.fn.strcharpart(name, 0, max_len) end
  return vim.fn.strcharpart(name, 0, max_len - 1) .. "…"
end

local function escape_pct(s)
  return s:gsub("%%", "%%%%")
end

local function pad(n)
  return n > 0 and string.rep(" ", n) or ""
end

function M.render(win)
  -- Lazy-init module refs on first render
  if not winbuf then winbuf = require("winbuf") end
  if not tracker then tracker = require("winbuf.tracker") end

  local config = winbuf.config
  local cur_buf = api.nvim_win_get_buf(win)
  local bufs = tracker.get_win_bufs(win)

  -- Filter out stale/unlisted buffers at render time (cheap, and keeps display clean)
  bufs = vim.tbl_filter(function(b)
    return api.nvim_buf_is_valid(b) and vim.bo[b].buflisted
  end, bufs)

  if #bufs == 0 then return "" end
  if config.hide_single and #bufs <= 1 then return "" end

  local left_sep, right_sep = winbuf.get_separators()
  local padding_str = pad(config.padding or 1)
  local max_name = config.max_name_length or 18
  local show_close = config.show_close_icon ~= false
  local show_ordinal = config.show_buffer_ordinal or false
  local do_truncate = config.truncate_names ~= false
  local diag_enabled = config.diagnostics and config.diagnostics ~= false
  local indicator = config.indicator and config.indicator.style or "bar"

  local has_devicons, devicons = false, nil
  if config.icons and config.icons.enabled then
    has_devicons, devicons = pcall(require, "nvim-web-devicons")
  end

  local parts = {}

  for idx, buf in ipairs(bufs) do
    local raw_name = vim.fn.fnamemodify(api.nvim_buf_get_name(buf), ":t")
    if raw_name == "" then raw_name = config.no_name end

    local display = raw_name
    if do_truncate then display = truncate(raw_name, max_name) end
    display = escape_pct(display)

    local active = buf == cur_buf
    local modified = vim.bo[buf].modified

    local hl = active and "%#WinBufActive#" or "%#WinBufInactive#"
    local sep_hl = active and "%#WinBufActiveSep#" or "%#WinBufInactiveSep#"
    local close_hl = active and "%#WinBufActiveClose#" or "%#WinBufInactiveClose#"
    local mod_hl = active and "%#WinBufActiveModified#" or "%#WinBufInactiveModified#"

    local content = {}

    if show_ordinal then
      table.insert(content, tostring(idx) .. " ")
    end

    -- File icon — use raw_name so the extension lookup is correct
    if has_devicons then
      local icon, icon_hl = devicons.get_icon(raw_name)
      if icon then
        if active and icon_hl then
          table.insert(content, "%#" .. icon_hl .. "#" .. icon .. " " .. hl)
        else
          table.insert(content, icon .. " ")
        end
      end
    end

    table.insert(content, display)

    if modified then
      table.insert(content, " " .. mod_hl .. config.modified_icon .. hl)
    end

    -- Diagnostics badges
    if diag_enabled then
      local counts = get_diagnostics(buf)
      local total = counts.error + counts.warning
      local diag_text = ""

      if total > 0 and config.diagnostics_indicator then
        local level = counts.error > 0 and "error" or "warning"
        diag_text = config.diagnostics_indicator(total, level, counts)
      elseif total > 0 then
        if counts.error > 0 then
          local dhl = active and "%#WinBufActiveDiagError#" or "%#WinBufInactiveDiagError#"
          diag_text = diag_text .. " " .. dhl .. " " .. counts.error .. hl
        end
        if counts.warning > 0 then
          local dhl = active and "%#WinBufActiveDiagWarn#" or "%#WinBufInactiveDiagWarn#"
          diag_text = diag_text .. " " .. dhl .. " " .. counts.warning .. hl
        end
      end

      if diag_text ~= "" then
        table.insert(content, diag_text)
      end
    end

    -- Close button
    local close_btn = ""
    if show_close then
      local click_fn = string.format("%%@v:lua.require'winbuf.render'.close_click_%d@", buf)
      close_btn = " " .. close_hl .. click_fn .. config.close_icon .. "%X" .. hl
    end

    -- Tab body click handler
    local click = string.format("%%@v:lua.require'winbuf.render'.switch_click_%d@", buf)

    local tab_content = table.concat(content, "")
    local tab

    if indicator == "underline" and active then
      local ul = "%#WinBufActiveUnderline#"
      tab = sep_hl .. left_sep
        .. ul .. click .. padding_str .. tab_content .. close_btn .. padding_str .. "%X"
        .. sep_hl .. right_sep
    else
      tab = sep_hl .. left_sep
        .. hl .. click .. padding_str .. tab_content .. close_btn .. padding_str .. "%X"
        .. sep_hl .. right_sep
    end

    table.insert(parts, tab)
  end

  return table.concat(parts, "") .. "%#WinBufFill#"
end

function M.eval_win(win)
  if not api.nvim_win_is_valid(win) then return "" end
  if vim.bo[api.nvim_win_get_buf(win)].buftype ~= "" then return "" end
  return M.render(win)
end

function M.refresh_all()
  for _, win in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_is_valid(win) then
      local bt = vim.bo[api.nvim_win_get_buf(win)].buftype
      if bt == "" then
        api.nvim_set_option_value(
          "winbar",
          "%{%v:lua.require'winbuf.render'.eval_win(" .. win .. ")%}",
          { win = win }
        )
      else
        api.nvim_set_option_value("winbar", "", { win = win })
      end
    end
  end
end

function M.prune_click_cache(buf)
  click_cache["switch_click_" .. buf] = nil
  click_cache["close_click_" .. buf] = nil
end

function M.setup()
  M.refresh_all()
end

-- Click handlers via metatable — cached so we're not creating closures on every render
setmetatable(M, {
  __index = function(_, key)
    if click_cache[key] then return click_cache[key] end

    local switch_id = key:match("^switch_click_(%d+)$")
    if switch_id then
      local buf = tonumber(switch_id)
      local fn = function(_, _, button, _)
        if button == "l" and api.nvim_buf_is_valid(buf) then
          api.nvim_set_current_buf(buf)
        elseif button == "m" then
          require("winbuf.actions").close_buf(buf)
        end
      end
      click_cache[key] = fn
      return fn
    end

    local close_id = key:match("^close_click_(%d+)$")
    if close_id then
      local buf = tonumber(close_id)
      local fn = function() require("winbuf.actions").close_buf(buf) end
      click_cache[key] = fn
      return fn
    end
  end,
})

return M
