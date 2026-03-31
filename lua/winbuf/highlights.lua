local M = {}
local api = vim.api

local hl_config = {}

local groups = {
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

local function apply()
  for _, def in ipairs(groups) do
    local hl = hl_config[def[2]]
    if hl then
      api.nvim_set_hl(0, def[1], {
        fg = hl.fg, bg = hl.bg,
        bold = hl.bold, italic = hl.italic,
        underline = hl.underline, sp = hl.sp,
      })
    end
  end
end

function M.setup(hl)
  hl_config = hl
  apply()

  api.nvim_create_autocmd("ColorScheme", {
    group = api.nvim_create_augroup("WinBufHighlights", { clear = true }),
    callback = apply,
  })
end

return M
