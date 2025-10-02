-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

map("n", "<c-h>", "<s-h>", { remap = true, desc = "Change to left buffer" })
map("n", "<c-l>", "<s-l>", { remap = true, desc = "Change to right buffer" })

map("n", "<c-p>", "<leader>fF", { remap = true, desc = "Open file picker" })
map("n", "<c-q>", "<leader>bD", { remap = true, desc = "Close buffer and window" })
map("n", "<c-e>", "<leader>e", { remap = true, desc = "Reveal file in file explorer" })

map("n", "<space>/", "<space>sG", { remap = true, desc = "Grep (cwd)" })

map("n", "gk", function()
  local on = not vim.diagnostic.config().virtual_lines
  vim.diagnostic.config({ virtual_lines = on })
end, { desc = "Toggle diagnostic virtual lines" })

map("n", "yp", function()
  vim.fn.setreg("+", vim.fn.expand("%"))
end, { desc = "Copy relative file path to clipboard" })

map("n", "yP", function()
  vim.fn.setreg("+", vim.fn.expand("%:p"))
end, { desc = "Copy absolute file path to clipboard" })

map("v", "yp", function()
  local relative_path = vim.fn.expand('%')
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  local result
  if start_line == end_line then
    result = string.format('%s:%d', relative_path, start_line)
  else
    result = string.format('%s:%d,%d', relative_path, start_line, end_line)
  end
  vim.fn.setreg('+', result)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', false)
end, { desc = 'Copy file path and range' })

map("n", "<leader>ga", function()
  local original_win = vim.api.nvim_get_current_win()
  vim.cmd("botright 10split | terminal zsh -l -i -c gaacyp")
  local terminal_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_create_autocmd("TermClose", {
    buffer = terminal_buf,
    once = true,
    callback = function()
      vim.api.nvim_buf_delete(terminal_buf, { force = true })
    end,
  })
  vim.api.nvim_set_current_win(original_win)
end, { desc = "Run gaacyp and close terminal" })
