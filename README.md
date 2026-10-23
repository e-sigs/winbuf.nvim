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
  resolve_modified = nil,   -- synchronous save/discard/cancel decision; defaults to a prompt
  eligible = nil,           -- optional additional window exclusion predicate
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

### Safe closing and eligibility

Closing a modified buffer's final group/display reference prompts for Save,
Discard, or Cancel (default). Cancel, a failed save, or an empty unnamed-save path
leaves membership and selection intact. Closing a group also checks its inactive
modified files. A shared buffer remains alive while another group or window
references it. Only an explicit Discard or `!` permits forced deletion.

**Compatibility change:** `buf_delete` is no longer accepted. A void callback
(such as an asynchronous deletion UI) cannot distinguish successful completion
from cancellation. Instead, `resolve_modified(buf)` may synchronously return
`"save"`, `"discard"`, or `"cancel"`; all other results cancel. The plugin owns
saving and deletion. Omit this option to use the built-in confirmation prompt.
Do not wrap an asynchronous `vim.ui.select` call in this synchronous hook.

```lua
require("winbuf").setup({
  -- Optional integration hook: return false for plugin-owned editor windows.
  eligible = function(win, buf)
    return not vim.w[win].my_plugin_window
  end,
})
```

Floating, preview, diff, and special-buftype windows are always excluded.
`vim.w.winbuf_exclude` and `vim.b.winbuf_exclude` also opt out. Eligibility applies
to tracking, rendering, cycling, moves, and closing; an exclusion never clears
another plugin's winbar. Existing nonempty third-party winbars are respected.

New splits start with their displayed file rather than copied inactive membership.
A final empty editor remains open; reusable empty buffers are unlisted and become
listed again when edited. Ordinary native `:close` does not invoke winbuf's
inactive-file checks: use `WinBufCloseSplit` for protected whole-group closing.
Save decisions can write files before a later prompt cancels a multi-file close.
Arbitrary third-party autocmd side effects cannot be rolled back. If orphan cleanup
fails after a group closes, surviving files are retained in another editor and a
warning is shown rather than silently abandoning them.

The action APIs return true on completion and false on cancellation/refusal.
No session persistence or session restoration is installed.

See [tests/README.md](tests/README.md) for reproduction and regression commands.

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
