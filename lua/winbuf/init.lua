-- winbuf.nvim - Per-window buffer tabs for Neovim
-- Renders buffer tabs in the winbar, scoped to each window (like VS Code editor groups)

local M = {}

--- @class WinBufConfig
--- @field icons? WinBufIcons
--- @field highlights? WinBufHighlights
--- @field close_icon? string
--- @field modified_icon? string
--- @field separator? string
--- @field no_name? string
--- @field hide_single? boolean
--- @field buf_delete? fun(buf: number)

--- @class WinBufIcons
--- @field enabled? boolean

--- @class WinBufHighlights
--- @field active? WinBufHl
--- @field active_sep? WinBufHl
--- @field inactive? WinBufHl
--- @field inactive_sep? WinBufHl

--- @class WinBufHl
--- @field fg? string
--- @field bg? string
--- @field bold? boolean
--- @field italic? boolean

--- @type WinBufConfig
M.config = {}

--- @type WinBufConfig
local defaults = {
  icons = {
    enabled = true,
  },
  close_icon = "󰅖",
  modified_icon = "●",
  separator = "▎",
  no_name = "[No Name]",
  hide_single = false,
  highlights = {
    active = { fg = "#ABB2BF", bg = "#2C313C", bold = true },
    active_sep = { fg = "#61AFEF", bg = "#2C313C" },
    inactive = { fg = "#5C6370", bg = "#22252C" },
    inactive_sep = { fg = "#3E4452", bg = "#22252C" },
  },
  buf_delete = nil,
}

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
