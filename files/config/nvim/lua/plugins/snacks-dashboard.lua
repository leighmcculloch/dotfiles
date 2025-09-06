return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      enabled = true,

      width = 120,
      preset = {
        header = [[
██╗   ██╗██╗███╗   ███╗
██║   ██║██║████╗ ████║
██║   ██║██║██╔████╔██║
╚██╗ ██╔╝██║██║╚██╔╝██║
╚████╔╝ ██║██║ ╚═╝ ██║
  ╚═══╝  ╚═╝╚═╝     ╚═╝
        ]],
          -- stylua: ignore
          ---@type snacks.dashboard.Item[]
          keys = {
            { icon = " ", key = "b", desc = "Browse", action = ":lua Snacks.gitbrowse()" },
            { icon = " ", key = "i", desc = "Issues", action = function() vim.fn.jobstart("gh issue list --web", { detach = true }) end },
            { icon = " ", key = "p", desc = "Pull Requests", action = function() vim.fn.jobstart("gh pr list --web", { detach = true }) end },
            --{ icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
            { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            --{ icon = " ", key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            --{ icon = " ", key = "x", desc = "Lazy Extras", action = ":LazyExtras" },
            --{ icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
            --{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
      },
      sections = {
        { section = "header" },
        { section = "keys", gap = 1, padding = 1 },
      },
    },
  },
}
