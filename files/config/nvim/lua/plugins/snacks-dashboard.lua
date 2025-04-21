return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      enabled = true,

      width = 120,
      preset = {
        header = [[
        ]],
          -- stylua: ignore
          ---@type snacks.dashboard.Item[]
          keys = {
            { icon = " ", key = "b", desc = "Browse", action = ":lua Snacks.gitbrowse()" },
            --{ icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
            --{ icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
            --{ icon = " ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
            --{ icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            --{ icon = " ", key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            --{ icon = " ", key = "x", desc = "Lazy Extras", action = ":LazyExtras" },
            --{ icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
            --{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
      },
      sections = {
        { section = "header" },
        { section = "keys", gap = 1, padding = 1 },
        function()
          local in_git = Snacks.git.get_root() ~= nil
          local cmds = {
            {
              title = "Notifications",
              cmd = "gh notify -s -a -n5",
              action = function()
                vim.ui.open("https://github.com/notifications")
              end,
              key = "n",
              icon = " ",
              height = 7,
              enabled = true,
              cache = true,
            },
            {
              title = "Open Issues",
              cmd = [[
                GH_PAGER= gh issue list -L 7 \
                --search 'sort:updated-desc assignee:@me' \
                --json number,title,assignees,updatedAt \
                --template '{{range .}}{{tablerow .number .title (join "," (pluck "login" .assignees)) (timeago .updatedAt)}}{{end}}{{tablerender}}' \
                && \
                GH_PAGER= gh issue list -L 7 \
                --search 'sort:updated-desc involves:@me -assignee:@me' \
                --json number,title,assignees,updatedAt \
                --template '{{range .}}{{tablerow .number .title (join "," (pluck "login" .assignees)) (timeago .updatedAt)}}{{end}}{{tablerender}}'
              ]],
              key = "i",
              action = function()
                vim.fn.jobstart("gh issue list --web", { detach = true })
              end,
              icon = " ",
              height = 7,
            },
            {
              icon = " ",
              title = "Open PRs",
              cmd = "gh pr list -L 3",
              key = "P",
              action = function()
                vim.fn.jobstart("gh pr list --web", { detach = true })
              end,
              height = 7,
            },
            {
              icon = " ",
              title = "Git Status",
              cmd = "git --no-pager diff --stat -B -M -C",
              height = 7,
            },
          }
          return vim.tbl_map(function(cmd)
            return vim.tbl_extend("force", {
              pane = 1,
              section = "terminal",
              enabled = in_git,
              padding = 1,
              ttl = 5 * 60,
              indent = 3,
            }, cmd)
          end, cmds)
        end,
      },
    },
  },
}
