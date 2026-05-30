-- Make dotfiles searchable in the explorer, file picker, and grep, while still
-- respecting gitignore. Exception: NOTES_*.md files are always shown even though
-- they're gitignored via ~/.gitignore_global ("NOTES_*.md").
--
-- The picker (file picker + grep) and the explorer use different mechanisms:
--   * picker: rg with --hidden, and a flag combo to re-include NOTES_*.md.
--   * explorer: its own tree, with hidden = true and an `include` glob.

local notes_glob = "NOTES_*.md"

-- rg/fd args that re-include NOTES_*.md even though it's in the *global*
-- gitignore. A negation can't override an ignore rule from a lower-precedence
-- source, and --ignore-file is lower precedence than the global gitignore, so a
-- plain negation doesn't work. Instead we: disable the global gitignore
-- (--no-ignore-global), re-add it as an --ignore-file, then add a second
-- --ignore-file holding the negation (a later --ignore-file wins over an earlier
-- one). The repo's own .gitignore is left untouched and still respected.
local function unignore_notes_args()
  local excludes = vim.trim(vim.fn.system({ "git", "config", "--global", "core.excludesfile" }))
  excludes = excludes ~= "" and vim.fn.expand(excludes) or nil
  if not excludes or vim.fn.filereadable(excludes) == 0 then
    return {}
  end
  local negation = vim.fn.stdpath("config") .. "/notes-visible.ignore"
  return { "--no-ignore-global", "--ignore-file", excludes, "--ignore-file", negation }
end

local args = unignore_notes_args()

return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        -- Explorer reads the directory tree itself (not via rg/fd in tree mode),
        -- so the `include` glob always shows NOTES_*.md regardless of gitignore.
        explorer = {
          hidden = true,
          include = { notes_glob },
        },
        -- Force rg so the NOTES re-include flags work (fd has no
        -- --no-ignore-global equivalent).
        files = {
          hidden = true,
          cmd = "rg",
          args = args,
        },
        grep = {
          hidden = true,
          args = args,
        },
      },
    },
  },
}
