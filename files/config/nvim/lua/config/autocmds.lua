-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Check if files changed on disk when focusing Neovim or switching buffers
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  group = vim.api.nvim_create_augroup("checktime", { clear = true }),
  pattern = "*",
  callback = function()
    if vim.o.buftype ~= "nofile" then
      vim.cmd("checktime")
    end
  end,
})

-- Watch current buffer file for external changes (instant reload without focus)
local watch_group = vim.api.nvim_create_augroup("file_watcher", { clear = true })
local watchers = {}

local function watch_buffer()
  local bufnr = vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  -- Skip if no file, already watching, or special buffer
  if filepath == "" or watchers[bufnr] or vim.bo[bufnr].buftype ~= "" then
    return
  end

  local w = vim.uv.new_fs_event()
  if not w then
    return
  end

  watchers[bufnr] = w

  w:start(
    filepath,
    {},
    vim.schedule_wrap(function(err, filename, events)
      if err then
        return
      end
      -- Reload the buffer if it still exists and is valid
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_call(bufnr, function()
          vim.cmd("checktime")
        end)
      end
    end)
  )
end

local function unwatch_buffer(bufnr)
  local w = watchers[bufnr]
  if w then
    w:stop()
    watchers[bufnr] = nil
  end
end

vim.api.nvim_create_autocmd("BufEnter", {
  group = watch_group,
  callback = watch_buffer,
})

vim.api.nvim_create_autocmd("BufDelete", {
  group = watch_group,
  callback = function(args)
    unwatch_buffer(args.buf)
  end,
})
