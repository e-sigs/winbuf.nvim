# winbuf.nvim

Per-window buffer tabs for Neovim. Like VS Code editor groups -- each split has its own tab bar showing only the buffers opened in that window.

![Demo](assets/demo.gif)

> Opening multiple files across two splits -- each window shows its own tab bar with only the buffers opened in that window. Cycling through buffers with `<S-h>` / `<S-l>` stays scoped to the current window.

No existing Neovim plugin does this. Bufferline, barbar, and others render in the global `tabline` -- one bar shared across all splits. **winbuf.nvim** renders in the **winbar** (`vim.wo.winbar`), which is per-window.

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
  - [Style Presets](#style-presets)
  - [Indicator Styles](#indicator-styles)
  - [Diagnostics](#diagnostics)
  - [Custom Separators](#custom-separators)
  - [Highlight Groups](#highlight-groups)
  - [Integration with Snacks.nvim](#integration-with-snacksnvim)
  - [Integration with mini.bufremove](#integration-with-minibufremove)
- [Commands](#commands)
- [API](#api)
- [How It Works](#how-it-works)
- [Author](#author)
- [License](#license)

## Features

- **Per-window buffer tracking** -- each split has its own buffer list
- **Multiple tab styles** -- thin, thick, slant, padded slant, slope, round
- **Active indicator styles** -- left bar, underline, or none
- **Clickable tabs** -- left-click to switch, middle-click to close
- **Close button** on each tab (toggleable)
- **File icons** via nvim-web-devicons (optional)
- **Modified indicator** -- shows when a buffer has unsaved changes
- **LSP diagnostics** -- error/warning counts per tab
- **Buffer ordinals** -- show tab position numbers
- **Name truncation** -- configurable max filename length
- **Configurable padding** -- control spacing inside tabs
- **Window-scoped cycling** -- navigate only buffers in the current window
- **Move buffers between splits** -- VS Code-style editor group transfers

![Move Buffers](assets/move-buffer.gif)

> Moving a buffer from one split to another with `<A-l>` / `<A-h>`. The buffer is removed from the source window's tab bar and appears in the target. If no split exists in that direction, one is created automatically.

- **Smart close** -- closing a buffer from one window keeps it alive in others

![Close Buffers](assets/close-buffer.gif)

> Closing a buffer with `<C-w>` removes it from the current window only. If another window is still tracking that buffer, it stays alive. If no window has it, the buffer is deleted entirely.

- **Smart split close** -- closing a split cleans up orphaned buffers
- **Fully configurable highlights** -- 14 highlight groups for total control
- **Fill background** -- style the empty space after tabs

## Requirements

- Neovim >= 0.9.0 (for winbar support)
- A Nerd Font (for separator and icon glyphs)
- [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) (optional, for file icons)

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "e-sigs/winbuf.nvim",
  event = "VeryLazy",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {},
  keys = {
    -- Cycle buffers within the current window group
    { "<S-h>", function() require("winbuf").cycle(-1) end, desc = "Previous buffer (window)" },
    { "<S-l>", function() require("winbuf").cycle(1) end, desc = "Next buffer (window)" },
    { "[b", function() require("winbuf").cycle(-1) end, desc = "Previous buffer (window)" },
    { "]b", function() require("winbuf").cycle(1) end, desc = "Next buffer (window)" },

    -- Move buffer to adjacent split (creates split if none exists)
    { "<A-h>", function() require("winbuf").move_buf("h") end, desc = "Move buffer left" },
    { "<A-l>", function() require("winbuf").move_buf("l") end, desc = "Move buffer right" },
    { "<A-j>", function() require("winbuf").move_buf("j") end, desc = "Move buffer down" },
    { "<A-k>", function() require("winbuf").move_buf("k") end, desc = "Move buffer up" },

    -- Close buffer from current window only
    { "<C-w>", function() require("winbuf").close_buf() end, desc = "Close buffer (window)" },

    -- Close split and clean up orphaned buffers
    { "<C-S-w>", function() require("winbuf").close_split() end, desc = "Close split" },
  },
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

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

These are the defaults. You only need to pass options you want to change.

```lua
require("winbuf").setup({
  -- Tab separator style preset
  -- Options: "thin", "thick", "slant", "padded_slant", "slope", "round"
  style = "thin",

  -- Or pass custom separator characters: { left, right }
  -- This overrides the style option
  separator_style = nil, -- e.g. { "|", "|" } or "slant"

  -- Active buffer indicator
  indicator = {
    style = "bar",  -- "bar" (left separator), "underline", "none"
    icon = nil,     -- Custom indicator icon (for bar style)
  },

  -- File icons (requires nvim-web-devicons)
  icons = {
    enabled = true,
  },

  -- Tab appearance
  close_icon = "󰅖",       -- Icon for the close button
  modified_icon = "●",     -- Icon for unsaved changes
  no_name = "[No Name]",   -- Display name for unnamed buffers

  -- Behavior
  hide_single = false,      -- Hide winbar when only one buffer in the window
  show_close_icon = true,   -- Show close button on tabs
  padding = 1,              -- Spaces on each side of tab content
  max_name_length = 18,     -- Truncate filenames longer than this
  truncate_names = true,    -- Enable filename truncation

  -- Buffer ordinals (show position number in tab)
  show_buffer_ordinal = false,

  -- LSP diagnostics per tab
  -- Set to "nvim_lsp" to show error/warning counts
  diagnostics = false,

  -- Custom diagnostics indicator function
  -- diagnostics_indicator = function(count, level, diagnostics_dict)
  --   local icon = level:match("error") and " " or " "
  --   return " " .. icon .. count
  -- end,

  -- Highlight groups (all configurable)
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

  -- Custom buffer delete function (e.g., Snacks.bufdelete or mini.bufremove)
  -- If nil, uses vim.api.nvim_buf_delete
  buf_delete = nil,
})
```

### Style Presets

Change the overall tab separator appearance with the `style` option:

![Style Presets](assets/styles.gif)

> Cycling through the 6 built-in separator styles: thin, thick, slant, padded slant, slope, and round. Switch styles with a single config option.

| Style | Left | Right | Description |
|-------|------|-------|-------------|
| `"thin"` | `▎` | | Thin left bar (default) |
| `"thick"` | `▌` | | Thick left bar |
| `"slant"` | `` | `` | Angled slant separators |
| `"padded_slant"` | ` ` | ` ` | Slant with padding |
| `"slope"` | `` | `` | Curved slope separators |
| `"round"` | `` | `` | Rounded separators |

```lua
-- Slant style (like bufferline)
require("winbuf").setup({ style = "slant" })

-- Or fully custom separators
require("winbuf").setup({ separator_style = { "", "" } })
```

### Indicator Styles

The active buffer indicator can be displayed in different ways:

| Style | Description |
|-------|-------------|
| `"bar"` | Colored left separator (default) |
| `"underline"` | Underline on the active tab |
| `"none"` | No special indicator |

```lua
-- Underline indicator (like bufferline)
require("winbuf").setup({
  indicator = { style = "underline" },
})
```

### Diagnostics

Show LSP diagnostic counts on each buffer tab:

```lua
require("winbuf").setup({
  diagnostics = "nvim_lsp",
})
```

With a custom indicator function:

```lua
require("winbuf").setup({
  diagnostics = "nvim_lsp",
  diagnostics_indicator = function(count, level, diagnostics_dict)
    local s = " "
    for e, n in pairs(diagnostics_dict) do
      local sym = e == "error" and " " or (e == "warning" and " " or " ")
      s = s .. n .. sym
    end
    return s
  end,
})
```

### Custom Separators

For full control over separator characters, pass a `{ left, right }` table:

```lua
-- Pipe separators
require("winbuf").setup({ separator_style = { "|", "|" } })

-- Arrow separators
require("winbuf").setup({ separator_style = { "", "" } })

-- Minimal (no separators)
require("winbuf").setup({ separator_style = { "", "" } })
```

### Highlight Groups

All highlight groups can be overridden. The plugin creates these Neovim highlight groups:

| Group | Used For |
|-------|----------|
| `WinBufActive` | Active tab text |
| `WinBufActiveSep` | Active tab separator |
| `WinBufInactive` | Inactive tab text |
| `WinBufInactiveSep` | Inactive tab separator |
| `WinBufActiveClose` | Active tab close icon |
| `WinBufInactiveClose` | Inactive tab close icon |
| `WinBufActiveModified` | Active tab modified icon |
| `WinBufInactiveModified` | Inactive tab modified icon |
| `WinBufActiveDiagError` | Active tab error diagnostic |
| `WinBufActiveDiagWarn` | Active tab warning diagnostic |
| `WinBufInactiveDiagError` | Inactive tab error diagnostic |
| `WinBufInactiveDiagWarn` | Inactive tab warning diagnostic |
| `WinBufFill` | Empty space after tabs |
| `WinBufActiveUnderline` | Underline indicator (when enabled) |

Highlights are automatically reapplied when you change colorscheme.

### Integration with Snacks.nvim

If you use [snacks.nvim](https://github.com/folke/snacks.nvim), pass its buffer delete function for a smoother experience:

```lua
require("winbuf").setup({
  buf_delete = function(buf)
    Snacks.bufdelete(buf)
  end,
})
```

### Integration with mini.bufremove

```lua
require("winbuf").setup({
  buf_delete = function(buf)
    require("mini.bufremove").delete(buf, false)
  end,
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:WinBufClose` | Close buffer from current window (keeps it in other windows) |
| `:WinBufCloseSplit` | Close split and delete orphaned buffers |
| `:WinBufMoveRight` | Move buffer to right split |
| `:WinBufMoveLeft` | Move buffer to left split |
| `:WinBufMoveDown` | Move buffer to bottom split |
| `:WinBufMoveUp` | Move buffer to top split |
| `:WinBufNext` | Next buffer in window group |
| `:WinBufPrev` | Previous buffer in window group |

## API

All actions are available as Lua functions:

```lua
local winbuf = require("winbuf")

winbuf.close_buf()         -- Close current buffer from window
winbuf.close_buf(bufnr)    -- Close specific buffer from window
winbuf.close_split()       -- Close split + orphaned buffers
winbuf.move_buf("l")       -- Move buffer right (h/j/k/l)
winbuf.cycle(1)            -- Next buffer in window
winbuf.cycle(-1)           -- Previous buffer in window
winbuf.refresh()           -- Refresh all winbars
```

## How It Works

1. **Tracking**: Each window maintains its own buffer list using Neovim's window-local variables (`vim.w`). When you open a file in a window, it's added to that window's list only.

2. **Rendering**: The winbar (`vim.wo.winbar`) is set per-window with a dynamic expression that calls the render function. Each window's winbar shows only its tracked buffers -- this is what makes it fundamentally different from tabline-based plugins.

3. **Moving**: When you move a buffer to another split, it's removed from the source window's list and added to the target. The source switches to its next available buffer (or closes if empty).

4. **Closing**: Closing a buffer from a window removes it from that window's tracking. If no other window is tracking it, the buffer is deleted entirely. If another window still has it, the buffer stays alive.

## Author

Signory Somsavath ([@e-sigs](https://github.com/e-sigs))

## License

[MIT](LICENSE) - Copyright (c) 2026 Signory Somsavath
