-- winbuf.nvim - Highlight group management

local M = {}
local api = vim.api

--- @type WinBufHighlights
local highlights = {}

--- Highlight group definitions: { name, config_key }
local hl_groups = {
  { "WinBufActive",            "active" },
  { "WinBufActiveSep",         "active_sep" },
  { "WinBufInactive",          "inactive" },
  { "WinBufInactiveSep",       "inactive_sep" },
  { "WinBufActiveClose",       "active_close" },
  { "WinBufInactiveClose",     "inactive_close" },
  { "WinBufActiveModified",    "active_modified" },
  { "WinBufInactiveModified",  "inactive_modified" },
  { "WinBufActiveDiagError",   "active_diag_error" },
  { "WinBufActiveDiagWarn",    "active_diag_warn" },
  { "WinBufInactiveDiagError", "inactive_diag_error" },
  { "WinBufInactiveDiagWarn",  "inactive_diag_warn" },
  { "WinBufFill",              "fill" },
  { "WinBufActiveUnderline",   "active_underline" },
}

--- Apply highlight groups
local function apply()
  for _, def in ipairs(hl_groups) do
    local name, key = def[1], def[2]
    local hl = highlights[key]
    if hl then
      api.nvim_set_hl(0, name, {
        fg = hl.fg,
        bg = hl.bg,
        bold = hl.bold,
        italic = hl.italic,
        underline = hl.underline,
        sp = hl.sp,
      })
    end
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
