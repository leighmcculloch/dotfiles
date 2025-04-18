return {
  "folke/edgy.nvim",
  opts = {
    left = {
      {
        title = "Explorer",
        ft = "snacks_layout_box",
        filter = function(buf, win) -- exclude floating windows
          return vim.api.nvim_win_get_config(win).relative == ""
        end,
        pinned = true,
      },
      {
        title = "Outline",
        ft = "Outline",
        pinned = true,
        open = "Outline",
      },
      {
        ft = "copilot-chat",
        title = "Copilot Chat",
        size = { width = 50 },
        pinned = true,
        open = "CopilotChat",
      },
    },
    animate = {
      enabled = false,
    },
  },
}
