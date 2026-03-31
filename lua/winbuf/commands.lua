local M = {}

function M.setup()
  local cmd = vim.api.nvim_create_user_command

  cmd("WinBufClose", function(c)
    local buf = nil
    if c.args ~= "" then
      buf = tonumber(c.args)
      if not buf then
        vim.notify("WinBufClose: invalid buffer number: " .. c.args, vim.log.levels.ERROR)
        return
      end
    end
    require("winbuf.actions").close_buf(buf, c.bang)
  end, { desc = "Close buffer from current window", bang = true, nargs = "?" })

  cmd("WinBufCloseSplit", function(c)
    require("winbuf.actions").close_split(c.bang)
  end, { desc = "Close split and orphaned buffers", bang = true })

  cmd("WinBufMoveRight", function() require("winbuf.actions").move_buf("l") end,
    { desc = "Move buffer to right split" })
  cmd("WinBufMoveLeft", function() require("winbuf.actions").move_buf("h") end,
    { desc = "Move buffer to left split" })
  cmd("WinBufMoveDown", function() require("winbuf.actions").move_buf("j") end,
    { desc = "Move buffer to bottom split" })
  cmd("WinBufMoveUp", function() require("winbuf.actions").move_buf("k") end,
    { desc = "Move buffer to top split" })

  cmd("WinBufNext", function() require("winbuf.actions").cycle(1) end,
    { desc = "Next buffer in window group" })
  cmd("WinBufPrev", function() require("winbuf.actions").cycle(-1) end,
    { desc = "Previous buffer in window group" })
end

return M
