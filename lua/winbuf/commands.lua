-- winbuf.nvim - User commands

local M = {}

function M.setup()
  vim.api.nvim_create_user_command("WinBufClose", function(cmd)
    local buf = nil
    if cmd.args and cmd.args ~= "" then
      buf = tonumber(cmd.args)
      if not buf then
        vim.notify("WinBufClose: invalid buffer number: " .. cmd.args, vim.log.levels.ERROR)
        return
      end
    end
    require("winbuf.actions").close_buf(buf, cmd.bang)
  end, { desc = "Close buffer from current window", bang = true, nargs = "?" })

  vim.api.nvim_create_user_command("WinBufCloseSplit", function(cmd)
    require("winbuf.actions").close_split(cmd.bang)
  end, { desc = "Close split and orphaned buffers", bang = true })

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
