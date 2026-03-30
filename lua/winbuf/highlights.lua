-- winbuf.nvim - Highlight group management

local M = {}
local api = vim.api

--- @type WinBufHighlights
local highlights = {}

--- Apply highlight groups
local function apply()
  if highlights.active then
    api.nvim_set_hl(0, "WinBufActive", {
      fg = highlights.active.fg,
      bg = highlights.active.bg,
      bold = highlights.active.bold,
      italic = highlights.active.italic,
    })
  end
  if highlights.active_sep then
    api.nvim_set_hl(0, "WinBufActiveSep", {
      fg = highlights.active_sep.fg,
      bg = highlights.active_sep.bg,
      bold = highlights.active_sep.bold,
      italic = highlights.active_sep.italic,
    })
  end
  if highlights.inactive then
    api.nvim_set_hl(0, "WinBufInactive", {
      fg = highlights.inactive.fg,
      bg = highlights.inactive.bg,
      bold = highlights.inactive.bold,
      italic = highlights.inactive.italic,
    })
  end
  if highlights.inactive_sep then
    api.nvim_set_hl(0, "WinBufInactiveSep", {
      fg = highlights.inactive_sep.fg,
      bg = highlights.inactive_sep.bg,
      bold = highlights.inactive_sep.bold,
      italic = highlights.inactive_sep.italic,
    })
  end
end

--- Setup highlights
--- @param hl WinBufHighlights
function M.setup(hl)
  highlights = hl
  apply()

  -- Reapply on colorscheme change
  api.nvim_create_autocmd("ColorScheme", {
    group = api.nvim_create_augroup("WinBufHighlights", { clear = true }),
    callback = apply,
  })
end

return M
