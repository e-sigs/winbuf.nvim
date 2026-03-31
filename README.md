# winbuf.nvim

Per-window buffer tabs for Neovim. Each split gets its own tab bar — like VS Code editor groups.

![Demo](assets/demo.gif)

Every bufferline plugin out there renders in the global `tabline` — one shared bar across all splits. That's fine until you start working with multiple splits and want each one to have its own set of tabs. **winbuf.nvim** uses the `winbar` instead, which is per-window, so each split shows only the buffers you've opened in it.

## Features

- Each split tracks its own buffer list independently
- Multiple tab styles (thin, thick, slant, slope, round)
- Clickable tabs — left-click to switch, middle-click to close
- File icons via nvim-web-devicons
- Modified indicator, LSP diagnostic counts, buffer ordinals
- Move buffers between splits with `<A-h/j/k/l>`
- Window-scoped close — closing a buffer in one split keeps it alive in others
- Closing a split cleans up any orphaned buffers

![Move Buffers](assets/move-buffer.gif)

![Close Buffers](assets/close-buffer.gif)

## Requirements

- Neovim >= 0.9.0
- A Nerd Font
- [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) (optional)

## Installation

### lazy.nvim

```lua
{
  "e-sigs/winbuf.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {},
  keys = {
    { "<S-h>", function() require("winbuf").cycle(-1) end, desc = "Prev buffer" },
    { "<S-l>", function() require("winbuf").cycle(1) end, desc = "Next buffer" },
    { "[b", function() require("winbuf").cycle(-1) end, desc = "Prev buffer" },
    { "]b", function() require("winbuf").cycle(1) end, desc = "Next buffer" },

    { "<A-h>", function() require("winbuf").move_buf("h") end, desc = "Move buffer left" },
    { "<A-l>", function() require("winbuf").move_buf("l") end, desc = "Move buffer right" },
    { "<A-j>", function() require("winbuf").move_buf("j") end, desc = "Move buffer down" },
    { "<A-k>", function() require("winbuf").move_buf("k") end, desc = "Move buffer up" },

    { "<C-w>", function() require("winbuf").close_buf() end, desc = "Close buffer (window)" },
    { "<C-S-w>", function() require("winbuf").close_split() end, desc = "Close split" },
  },
}
```

### packer.nvim

```lua
use {
  "e-sigs/winbuf.nvim",
  requires = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("winbuf").setup()
  end,
}
```

## Configuration

Pass only what you want to change — everything has sane defaults.

```lua
require("winbuf").setup({
  style = "thin",           -- "thin", "thick", "slant", "padded_slant", "slope", "round"
  separator_style = nil,    -- override with { left, right } or a preset name
  indicator = {
    style = "bar",          -- "bar", "underline", "none"
  },
  icons = { enabled = true },
  close_icon = "󰅖",
  modified_icon = "●",
  no_name = "[No Name]",
  hide_single = false,
  show_close_icon = true,
  padding = 1,
  max_name_length = 18,
  truncate_names = true,
  show_buffer_ordinal = false,
  diagnostics = false,      -- set to "nvim_lsp" to enable
  buf_delete = nil,         -- custom delete fn, e.g. Snacks.bufdelete
})
```

### Style Presets

![Style Presets](assets/styles.gif)

| Style | Left | Right |
|-------|------|-------|
| `"thin"` | `▎` | |
| `"thick"` | `▌` | |
| `"slant"` | `` | `` |
| `"padded_slant"` | ` ` | ` ` |
| `"slope"` | `` | `` |
| `"round"` | `` | `` |

### Diagnostics

```lua
require("winbuf").setup({
  diagnostics = "nvim_lsp",
  -- optional custom indicator
  diagnostics_indicator = function(count, level, diagnostics_dict)
    local icon = level:match("error") and " " or " "
    return " " .. icon .. count
  end,
})
```

### Custom Buffer Delete

Works with [snacks.nvim](https://github.com/folke/snacks.nvim) or [mini.bufremove](https://github.com/echasnovski/mini.bufremove):

```lua
-- snacks
buf_delete = function(buf) Snacks.bufdelete(buf) end

-- mini.bufremove
buf_delete = function(buf) require("mini.bufremove").delete(buf, false) end
```

### Highlight Groups

The plugin defines 14 highlight groups. Override them in the `highlights` table or with `nvim_set_hl` after setup. They're reapplied automatically on colorscheme change.

`WinBufActive`, `WinBufActiveSep`, `WinBufInactive`, `WinBufInactiveSep`, `WinBufActiveClose`, `WinBufInactiveClose`, `WinBufActiveModified`, `WinBufInactiveModified`, `WinBufActiveDiagError`, `WinBufActiveDiagWarn`, `WinBufInactiveDiagError`, `WinBufInactiveDiagWarn`, `WinBufFill`, `WinBufActiveUnderline`

## Commands

| Command | Description |
|---------|-------------|
| `:WinBufClose [bufnr]` | Close buffer from current window. Supports `!` for force. |
| `:WinBufCloseSplit` | Close split, delete orphaned buffers. Supports `!`. |
| `:WinBufMoveRight/Left/Down/Up` | Move buffer to adjacent split |
| `:WinBufNext` / `:WinBufPrev` | Cycle buffers in current window |

## API

```lua
local winbuf = require("winbuf")

winbuf.close_buf()         -- close current buffer from window
winbuf.close_buf(bufnr)    -- close specific buffer
winbuf.close_split()       -- close split + orphaned buffers
winbuf.move_buf("l")       -- move buffer right (h/j/k/l)
winbuf.cycle(1)            -- next buffer in window
winbuf.cycle(-1)           -- previous buffer
winbuf.refresh()           -- force refresh all winbars
```

## How It Works

Each window keeps its own buffer list in a window-local variable (`vim.w`). The winbar (`vim.wo.winbar`) is set per-window with a dynamic expression that renders only that window's tracked buffers. When you move a buffer between splits, it's removed from the source and added to the target. When you close a buffer from a window, it only gets fully deleted if no other window is still tracking it.

## Author

Signory Somsavath ([@e-sigs](https://github.com/e-sigs))

## License

[MIT](LICENSE)
