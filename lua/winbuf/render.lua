-- winbuf.nvim - Winbar rendering

local M = {}
local api = vim.api

--- Render the winbar for a given window
--- @param win number
--- @return string
function M.render(win)
  local config = require("winbuf").config
  local tracker = require("winbuf.tracker")

  local cur_buf = api.nvim_win_get_buf(win)
  local bufs = tracker.get_win_bufs(win)

  if #bufs == 0 then
    return ""
  end

  if config.hide_single and #bufs <= 1 then
    return ""
  end

  local has_devicons, devicons = false, nil
  if config.icons and config.icons.enabled then
    has_devicons, devicons = pcall(require, "nvim-web-devicons")
  end

  local parts = {}

  for _, buf in ipairs(bufs) do
    local name = vim.fn.fnamemodify(api.nvim_buf_get_name(buf), ":t")
    if name == "" then
      name = config.no_name
    end

    local is_active = buf == cur_buf
    local is_modified = vim.bo[buf].modified

    -- File icon
    local icon = ""
    if has_devicons then
      local ft_icon, _ = devicons.get_icon(name)
      if ft_icon then
        icon = ft_icon .. " "
      end
    end

    -- Highlight groups
    local hl = is_active and "%#WinBufActive#" or "%#WinBufInactive#"
    local sep_hl = is_active and "%#WinBufActiveSep#" or "%#WinBufInactiveSep#"
    local mod_indicator = is_modified and (" " .. config.modified_icon) or ""

    -- Click handler to switch buffer
    local click = string.format("%%@v:lua.require'winbuf.render'.switch_click_%d@", buf)

    -- Close button click handler
    local close_click = string.format("%%@v:lua.require'winbuf.render'.close_click_%d@", buf)
    local close_btn = " " .. close_click .. config.close_icon .. "%X"

    table.insert(parts,
      sep_hl .. config.separator .. hl .. click .. " " .. icon .. name .. mod_indicator .. close_btn .. " %X"
    )
  end

  return table.concat(parts, "")
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
