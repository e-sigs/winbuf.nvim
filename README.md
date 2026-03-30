# winbuf.nvim

Per-window buffer tabs for Neovim. Like VS Code editor groups — each split has its own tab bar showing only the buffers opened in that window.

```
┌──────────────────────────────┬──────────────────────────────┐
│ ▎ main.go  ▎ utils.go  󰅖   │ ▎ config.yaml  ▎ deploy.tf  │
│                              │                              │
│   (left editor group)        │   (right editor group)       │
│                              │                              │
└──────────────────────────────┴──────────────────────────────┘
```

No existing Neovim plugin does this. Bufferline, barbar, and others render in the global tabline — one bar shared across all splits. **winbuf.nvim** renders in the **winbar**, which is per-window.

## Features

- **Per-window buffer tracking** — each split has its own buffer list
- **Active tab highlighting** — distinct colors for the focused buffer
- **Modified indicator** — shows when a buffer has unsaved changes
- **File icons** — via nvim-web-devicons (optional)
- **Clickable tabs** — left-click to switch, middle-click to close
- **Close button** on each tab
- **Window-scoped cycling** — navigate only buffers in the current window
- **Move buffers between splits** — VS Code-style editor group transfers
- **Smart close** — closing a buffer from one window keeps it alive in others
- **Smart split close** — closing a split cleans up orphaned buffers
- **Fully configurable** — highlights, icons, separators, delete behavior

## Requirements

- Neovim >= 0.9.0 (for winbar support)
- [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) (optional, for file icons)

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-username/winbuf.nvim",
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
  "your-username/winbuf.nvim",
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
  -- File icons (requires nvim-web-devicons)
  icons = {
    enabled = true,
  },

  -- Tab appearance
  close_icon = "󰅖",       -- Icon for the close button
  modified_icon = "●",     -- Icon for unsaved changes
  separator = "▎",         -- Left edge separator for each tab
  no_name = "[No Name]",   -- Display name for unnamed buffers

  -- Behavior
  hide_single = false,     -- Hide winbar when only one buffer in the window

  -- Highlight groups
  highlights = {
    active     = { fg = "#ABB2BF", bg = "#2C313C", bold = true },
    active_sep = { fg = "#61AFEF", bg = "#2C313C" },
    inactive     = { fg = "#5C6370", bg = "#22252C" },
    inactive_sep = { fg = "#3E4452", bg = "#22252C" },
  },

  -- Custom buffer delete function (e.g., Snacks.bufdelete or mini.bufremove)
  -- If nil, uses vim.api.nvim_buf_delete
  buf_delete = nil,
})
```

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

1. **Tracking**: Each window maintains its own buffer list using Neovim's window-local variables (`vim.w`). When you open a file in a window, it's added to that window's list.

2. **Rendering**: The winbar (`vim.wo.winbar`) is set per-window with a dynamic expression that calls the render function. Each window's winbar shows only its tracked buffers.

3. **Moving**: When you move a buffer to another split, it's removed from the source window's list and added to the target. The source switches to its next available buffer (or closes if empty).

4. **Closing**: Closing a buffer from a window removes it from that window's tracking. If no other window is tracking it, the buffer is deleted entirely. If another window still has it, the buffer stays alive.

## License

MIT
