-- winbuf.nvim - Per-window buffer tabs for Neovim
-- Renders buffer tabs in the winbar, scoped to each window (like VS Code editor groups)

local M = {}

--- @class WinBufConfig
--- @field style? string Tab separator style: "thin", "slant", "padded_slant", "slope", "thick"
--- @field separator_style? string|string[] Custom separators: preset name or { left, right } table
--- @field indicator? WinBufIndicator Active buffer indicator configuration
--- @field icons? WinBufIcons File icon configuration
--- @field highlights? WinBufHighlights Highlight group overrides
--- @field close_icon? string Icon for the close button on each tab
--- @field modified_icon? string Icon shown when buffer has unsaved changes
--- @field no_name? string Display name for unnamed buffers
--- @field hide_single? boolean Hide winbar when only one buffer in the window
--- @field show_close_icon? boolean Show close button on tabs
--- @field padding? number Number of spaces on each side of tab content
--- @field max_name_length? number Truncate filenames longer than this
--- @field diagnostics? boolean|string false or "nvim_lsp" to show diagnostic counts
--- @field diagnostics_indicator? fun(count: number, level: string, diagnostics_dict: table): string
--- @field show_buffer_ordinal? boolean Show buffer position number in tab
--- @field truncate_names? boolean Truncate long filenames with ellipsis
--- @field buf_delete? fun(buf: number) Custom buffer delete function
--- @field fill_hl? string Background highlight group name for empty winbar space

--- @class WinBufIndicator
--- @field style? string "bar" (left separator), "underline", "none"
--- @field icon? string Custom indicator icon (for bar style)

--- @class WinBufIcons
--- @field enabled? boolean Enable file type icons (requires nvim-web-devicons)

--- @class WinBufHighlights
--- @field active? WinBufHl
--- @field active_sep? WinBufHl
--- @field inactive? WinBufHl
--- @field inactive_sep? WinBufHl
--- @field active_close? WinBufHl
--- @field inactive_close? WinBufHl
--- @field active_modified? WinBufHl
--- @field inactive_modified? WinBufHl
--- @field active_diag_error? WinBufHl
--- @field active_diag_warn? WinBufHl
--- @field inactive_diag_error? WinBufHl
--- @field inactive_diag_warn? WinBufHl
--- @field fill? WinBufHl
--- @field active_underline? WinBufHl

--- @class WinBufHl
--- @field fg? string
--- @field bg? string
--- @field bold? boolean
--- @field italic? boolean
--- @field underline? boolean
--- @field sp? string Special color (for underline)

--- @type WinBufConfig
M.config = {}

--- Separator presets: { left_char, right_char }
M.separator_presets = {
  thin      = { "▎", "" },
  thick     = { "▌", "" },
  slant     = { "", "" },
  padded_slant = { " ", " " },
  slope     = { "", "" },
  round     = { "", "" },
}

--- @type WinBufConfig
local defaults = {
  style = "thin",
  separator_style = nil,
  indicator = {
    style = "bar",
    icon = nil,
  },
  icons = {
    enabled = true,
  },
  close_icon = "󰅖",
  modified_icon = "●",
  no_name = "[No Name]",
  hide_single = false,
  show_close_icon = true,
  padding = 1,
  max_name_length = 18,
  diagnostics = false,
  diagnostics_indicator = nil,
  show_buffer_ordinal = false,
  truncate_names = true,
  fill_hl = nil,
  highlights = {
    active          = { fg = "#ABB2BF", bg = "#2C313C", bold = true },
    active_sep      = { fg = "#61AFEF", bg = "#2C313C" },
    inactive        = { fg = "#5C6370", bg = "#22252C" },
    inactive_sep    = { fg = "#3E4452", bg = "#22252C" },
    active_close    = { fg = "#E06C75", bg = "#2C313C" },
    inactive_close  = { fg = "#5C6370", bg = "#22252C" },
    active_modified = { fg = "#E5C07B", bg = "#2C313C" },
    inactive_modified = { fg = "#5C6370", bg = "#22252C" },
    active_diag_error  = { fg = "#E06C75", bg = "#2C313C", bold = true },
    active_diag_warn   = { fg = "#E5C07B", bg = "#2C313C" },
    inactive_diag_error = { fg = "#E06C75", bg = "#22252C" },
    inactive_diag_warn  = { fg = "#E5C07B", bg = "#22252C" },
    fill = { bg = "#1E2127" },
    active_underline = { sp = "#61AFEF", underline = true },
  },
  buf_delete = nil,
}

--- Get resolved separator characters { left, right }
--- @return string, string
function M.get_separators()
  local sep = M.config.separator_style
  if sep then
    if type(sep) == "table" then
      return sep[1] or "", sep[2] or ""
    end
    if type(sep) == "string" and M.separator_presets[sep] then
      local preset = M.separator_presets[sep]
      return preset[1], preset[2]
    end
  end
  -- Fall back to style preset
  local style = M.config.style or "thin"
  local preset = M.separator_presets[style]
  if preset then
    return preset[1], preset[2]
  end
  return "▎", ""
end

--- Setup winbuf.nvim
--- @param opts? WinBufConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})

  require("winbuf.highlights").setup(M.config.highlights)
  require("winbuf.tracker").setup()
  require("winbuf.render").setup()
  require("winbuf.commands").setup()
end

-- Public API (re-exported from submodules for convenience)

--- Close a buffer from the current window only.
--- If the buffer isn't tracked in any other window, it gets deleted entirely.
--- @param buf? number Buffer to close (defaults to current buffer)
function M.close_buf(buf)
  require("winbuf.actions").close_buf(buf)
end

--- Close the current split and delete any buffers not tracked in other windows.
function M.close_split()
  require("winbuf.actions").close_split()
end

--- Move the current buffer to an adjacent split.
--- If no split exists in that direction, one is created.
--- @param direction string One of "h", "j", "k", "l"
function M.move_buf(direction)
  require("winbuf.actions").move_buf(direction)
end

--- Cycle through buffers in the current window's group.
--- @param offset number Positive for next, negative for previous
function M.cycle(offset)
  require("winbuf.actions").cycle(offset)
end

--- Remove a buffer from a specific window's tracking.
--- @param win number Window handle
--- @param buf number Buffer handle
function M.remove_buf_from_win(win, buf)
  require("winbuf.tracker").remove_buf_from_win(win, buf)
end

--- Refresh the winbar for all windows.
function M.refresh()
  require("winbuf.render").refresh_all()
end

return M
