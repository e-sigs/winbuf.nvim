-- winbuf.nvim - Winbar rendering

local M = {}
local api = vim.api

--- Get diagnostic counts for a buffer
--- @param buf number
--- @return table<string, number> { error = n, warning = n }
local function get_diagnostics(buf)
  local counts = { error = 0, warning = 0 }
  if not api.nvim_buf_is_valid(buf) then
    return counts
  end
  local diags = vim.diagnostic.get(buf)
  for _, d in ipairs(diags) do
    if d.severity == vim.diagnostic.severity.ERROR then
      counts.error = counts.error + 1
    elseif d.severity == vim.diagnostic.severity.WARN then
      counts.warning = counts.warning + 1
    end
  end
  return counts
end

--- Truncate a name to max_len characters with ellipsis
--- @param name string
--- @param max_len number
--- @return string
local function truncate(name, max_len)
  if not max_len or max_len <= 0 or #name <= max_len then
    return name
  end
  if max_len <= 3 then
    return name:sub(1, max_len)
  end
  return name:sub(1, max_len - 1) .. "…"
end

--- Generate padding string
--- @param n number
--- @return string
local function pad(n)
  if n <= 0 then return "" end
  return string.rep(" ", n)
end

--- Render the winbar for a given window
--- @param win number
--- @return string
function M.render(win)
  local winbuf = require("winbuf")
  local config = winbuf.config
  local tracker = require("winbuf.tracker")

  local cur_buf = api.nvim_win_get_buf(win)
  local bufs = tracker.get_win_bufs(win)

  if #bufs == 0 then
    return ""
  end

  if config.hide_single and #bufs <= 1 then
    return ""
  end

  -- Resolve settings
  local left_sep, right_sep = winbuf.get_separators()
  local padding_str = pad(config.padding or 1)
  local max_name = config.max_name_length or 18
  local show_close = config.show_close_icon ~= false
  local show_ordinal = config.show_buffer_ordinal or false
  local do_truncate = config.truncate_names ~= false
  local diag_enabled = config.diagnostics and config.diagnostics ~= false
  local indicator_style = config.indicator and config.indicator.style or "bar"

  -- Devicons
  local has_devicons, devicons = false, nil
  if config.icons and config.icons.enabled then
    has_devicons, devicons = pcall(require, "nvim-web-devicons")
  end

  local parts = {}

  for idx, buf in ipairs(bufs) do
    local name = vim.fn.fnamemodify(api.nvim_buf_get_name(buf), ":t")
    if name == "" then
      name = config.no_name
    end

    if do_truncate then
      name = truncate(name, max_name)
    end

    local is_active = buf == cur_buf
    local is_modified = vim.bo[buf].modified

    -- Highlight groups
    local hl = is_active and "%#WinBufActive#" or "%#WinBufInactive#"
    local sep_hl = is_active and "%#WinBufActiveSep#" or "%#WinBufInactiveSep#"
    local close_hl = is_active and "%#WinBufActiveClose#" or "%#WinBufInactiveClose#"
    local mod_hl = is_active and "%#WinBufActiveModified#" or "%#WinBufInactiveModified#"

    -- Build tab content pieces
    local content = {}

    -- Ordinal number
    if show_ordinal then
      table.insert(content, tostring(idx) .. " ")
    end

    -- File icon
    if has_devicons then
      local ft_icon, icon_hl = devicons.get_icon(name)
      if ft_icon then
        -- Use devicon highlight for active tab, dimmed for inactive
        if is_active and icon_hl then
          table.insert(content, "%#" .. icon_hl .. "#" .. ft_icon .. " " .. hl)
        else
          table.insert(content, ft_icon .. " ")
        end
      end
    end

    -- File name
    table.insert(content, name)

    -- Modified indicator
    if is_modified then
      table.insert(content, " " .. mod_hl .. config.modified_icon .. hl)
    end

    -- Diagnostics
    if diag_enabled then
      local counts = get_diagnostics(buf)
      local diag_text = ""

      if config.diagnostics_indicator then
        diag_text = config.diagnostics_indicator(
          counts.error + counts.warning,
          counts.error > 0 and "error" or "warning",
          counts,
          { buffer = buf }
        )
      else
        if counts.error > 0 then
          local diag_hl = is_active and "%#WinBufActiveDiagError#" or "%#WinBufInactiveDiagError#"
          diag_text = diag_text .. " " .. diag_hl .. " " .. counts.error .. hl
        end
        if counts.warning > 0 then
          local diag_hl = is_active and "%#WinBufActiveDiagWarn#" or "%#WinBufInactiveDiagWarn#"
          diag_text = diag_text .. " " .. diag_hl .. " " .. counts.warning .. hl
        end
      end

      if diag_text ~= "" then
        table.insert(content, diag_text)
      end
    end

    -- Close button
    local close_btn = ""
    if show_close then
      local close_click = string.format("%%@v:lua.require'winbuf.render'.close_click_%d@", buf)
      close_btn = " " .. close_hl .. close_click .. config.close_icon .. "%X" .. hl
    end

    -- Click handler for the tab body
    local click = string.format("%%@v:lua.require'winbuf.render'.switch_click_%d@", buf)

    -- Assemble the tab
    local tab_content = table.concat(content, "")
    local tab_str

    if indicator_style == "underline" and is_active then
      -- Underline indicator: the whole active tab gets underlined
      local ul_hl = "%#WinBufActiveUnderline#"
      tab_str = sep_hl .. left_sep
        .. ul_hl .. click .. padding_str .. tab_content .. close_btn .. padding_str .. "%X"
        .. sep_hl .. right_sep
    else
      -- Bar or none indicator: left separator acts as the indicator
      tab_str = sep_hl .. left_sep
        .. hl .. click .. padding_str .. tab_content .. close_btn .. padding_str .. "%X"
        .. sep_hl .. right_sep
    end

    table.insert(parts, tab_str)
  end

  -- Fill remaining space with fill highlight
  local fill = "%#WinBufFill#"
  return table.concat(parts, "") .. fill
end

--- Evaluate winbar for a specific window (called from winbar expression)
--- @param win number
--- @return string
function M.eval_win(win)
  if not api.nvim_win_is_valid(win) then
    return ""
  end
  local buf = api.nvim_win_get_buf(win)
  if vim.bo[buf].buftype ~= "" then
    return ""
  end
  return M.render(win)
end

--- Refresh winbar for all windows
function M.refresh_all()
  for _, win in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_is_valid(win) then
      local buf = api.nvim_win_get_buf(win)
      local bt = vim.bo[buf].buftype
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

--- Setup rendering
function M.setup()
  M.refresh_all()
end

-- Dynamic click handlers via metatable
setmetatable(M, {
  __index = function(_, key)
    local switch_buf = key:match("^switch_click_(%d+)$")
    if switch_buf then
      local buf = tonumber(switch_buf)
      return function(_, _, button, _)
        if button == "l" then
          if api.nvim_buf_is_valid(buf) then
            api.nvim_set_current_buf(buf)
          end
        elseif button == "m" then
          require("winbuf.actions").close_buf(buf)
        end
      end
    end

    local close_buf = key:match("^close_click_(%d+)$")
    if close_buf then
      local buf = tonumber(close_buf)
      return function(_, _, _, _)
        require("winbuf.actions").close_buf(buf)
      end
    end
  end,
})

return M
