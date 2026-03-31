-- winbuf.nvim — per-window buffer tabs rendered in the winbar

local M = {}

M.config = {}

M.separator_presets = {
  thin         = { "▎", "" },
  thick        = { "▌", "" },
  slant        = { "", "" },
  padded_slant = { " ", " " },
  slope        = { "", "" },
  round        = { "", "" },
}

local defaults = {
  style = "thin",
  separator_style = nil,
  indicator = { style = "bar", icon = nil },
  icons = { enabled = true },
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
  buf_delete = nil,
  highlights = {
    active              = { fg = "#ABB2BF", bg = "#2C313C", bold = true },
    active_sep          = { fg = "#61AFEF", bg = "#2C313C" },
    inactive            = { fg = "#5C6370", bg = "#22252C" },
    inactive_sep        = { fg = "#3E4452", bg = "#22252C" },
    active_close        = { fg = "#E06C75", bg = "#2C313C" },
    inactive_close      = { fg = "#5C6370", bg = "#22252C" },
    active_modified     = { fg = "#E5C07B", bg = "#2C313C" },
    inactive_modified   = { fg = "#5C6370", bg = "#22252C" },
    active_diag_error   = { fg = "#E06C75", bg = "#2C313C", bold = true },
    active_diag_warn    = { fg = "#E5C07B", bg = "#2C313C" },
    inactive_diag_error = { fg = "#E06C75", bg = "#22252C" },
    inactive_diag_warn  = { fg = "#E5C07B", bg = "#22252C" },
    fill                = { bg = "#1E2127" },
    active_underline    = { sp = "#61AFEF", underline = true },
  },
}

function M.get_separators()
  local sep = M.config.separator_style
  if sep then
    if type(sep) == "table" then return sep[1] or "", sep[2] or "" end
    if type(sep) == "string" and M.separator_presets[sep] then
      local p = M.separator_presets[sep]
      return p[1], p[2]
    end
  end
  local p = M.separator_presets[M.config.style or "thin"]
  if p then return p[1], p[2] end
  return "▎", ""
end

function M.setup(opts)
  opts = opts or {}

  -- Only validate the stuff that would produce confusing errors
  vim.validate({
    separator_style = { opts.separator_style, { "string", "table" }, true },
    diagnostics = { opts.diagnostics, { "boolean", "string" }, true },
    buf_delete = { opts.buf_delete, "function", true },
  })

  M.config = vim.tbl_deep_extend("force", defaults, opts)

  require("winbuf.highlights").setup(M.config.highlights)
  require("winbuf.tracker").setup()
  require("winbuf.render").setup()
  require("winbuf.commands").setup()
end

-- Public API

function M.close_buf(buf, force)
  require("winbuf.actions").close_buf(buf, force)
end

function M.close_split(force)
  require("winbuf.actions").close_split(force)
end

function M.move_buf(direction)
  require("winbuf.actions").move_buf(direction)
end

function M.cycle(offset)
  require("winbuf.actions").cycle(offset)
end

function M.remove_buf_from_win(win, buf)
  require("winbuf.tracker").remove_buf_from_win(win, buf)
end

function M.refresh()
  require("winbuf.render").refresh_all()
end

return M
