-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

map("n", "<c-h>", "<s-h>", { remap = true, desc = "Change to left buffer" })
map("n", "<c-l>", "<s-l>", { remap = true, desc = "Change to right buffer" })

map("n", "<c-p>", "<leader> ", { remap = true, desc = "Open file picker" })
map("n", "<c-q>", "<leader>bD", { remap = true, desc = "Close buffer and window" })
map("n", "<c-e>", "<leader>e", { remap = true, desc = "Reveal file in file explorer" })

map("n", "gk", function()
  local on = not vim.diagnostic.config().virtual_lines
  vim.diagnostic.config({ virtual_lines = on })
end, { desc = "Toggle diagnostic virtual lines" })
