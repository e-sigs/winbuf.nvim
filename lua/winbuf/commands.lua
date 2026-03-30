-- winbuf.nvim - User commands

local M = {}

function M.setup()
  vim.api.nvim_create_user_command("WinBufClose", function()
    require("winbuf.actions").close_buf()
  end, { desc = "Close buffer from current window" })

  vim.api.nvim_create_user_command("WinBufCloseSplit", function()
    require("winbuf.actions").close_split()
  end, { desc = "Close split and orphaned buffers" })

  vim.api.nvim_create_user_command("WinBufMoveRight", function()
    require("winbuf.actions").move_buf("l")
  end, { desc = "Move buffer to right split" })

  vim.api.nvim_create_user_command("WinBufMoveLeft", function()
    require("winbuf.actions").move_buf("h")
  end, { desc = "Move buffer to left split" })

  vim.api.nvim_create_user_command("WinBufMoveDown", function()
    require("winbuf.actions").move_buf("j")
  end, { desc = "Move buffer to bottom split" })

  vim.api.nvim_create_user_command("WinBufMoveUp", function()
    require("winbuf.actions").move_buf("k")
  end, { desc = "Move buffer to top split" })

  vim.api.nvim_create_user_command("WinBufNext", function()
    require("winbuf.actions").cycle(1)
  end, { desc = "Next buffer in window group" })

  vim.api.nvim_create_user_command("WinBufPrev", function()
    require("winbuf.actions").cycle(-1)
  end, { desc = "Previous buffer in window group" })
end

return M
