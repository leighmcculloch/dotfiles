return {
  "folke/edgy.nvim",
  opts = function(_, opts)
    local step = 15
    opts.keys = {
      -- increase width
      ["<c-<>"] = function(win)
        win:resize("width", step)
      end,
      -- decrease width
      ["<c->>"] = function(win)
        win:resize("width", 0 - step)
      end,
    }
    opts.animate = {
      enabled = false,
    }
  end,
  --opts = {
  --  --right = {
  --  --  {
  --  --    title = "Outline",
  --  --    ft = "Outline",
  --  --    pinned = true,
  --  --    open = "Outline",
  --  --  },
  --  --  --For CopilotC-Nvim/CopilotChat.nvim
  --  --  --{
  --  --  --  ft = "copilot-chat",
  --  --  --  title = "Copilot Chat",
  --  --  --  size = { width = 50 },
  --  --  --  pinned = true,
  --  --  --  open = "CopilotChat",
  --  --  --},
  --  --},
  --  animate = {
  --    enabled = false,
  --  },
  --  
  --  end
  --},
}
