vim.cmd([[
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vim/vimrc
]])

local bufferline = require("bufferline")
bufferline.setup {
  options = {
    indicator = { style = 'none' },
    separator_style = 'slant',
    tab_size = 10,
    diagnostics = "nvim_lsp",
    diagnostics_update_on_event = true, -- use nvim's diagnostic handler
    --offsets = { { filetype = "NvimTree", text = 'Files', text_align = 'left' } },
    sort_by = 'relative_directory',
  }
}

require('lualine').setup{
  options = {
    extensions = {'nvim-tree'},
  },
  sections = {
    lualine_a = {'mode'},
    lualine_b = {'branch', 'diff', 'diagnostics'},
    lualine_c = {
      {
        'filename',
        file_status = true,
        newfile_status = false,
        path = 1,
        shorting_target = 40,
        symbols = {
          modified = '[+]',
          readonly = '[-]',
          unnamed = '[No Name]',
          newfile = '[New]',
        }
      },
    },
    lualine_x = {
      {
        'lsp_status',
        icon = '',
        symbols = {
          spinner = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' },
          done = '✓',
          separator = ' ',
        },
        ignore_lsp = {'GitHub Copilot'},
      }
    },
    lualine_y = {'filetype'},
    lualine_z = {'progress', 'location'}
  }
}

local cmp = require'cmp'
cmp.setup({
  snippet = {
    expand = function(args)
      vim.snippet.expand(args.body)
    end,
  },
  window = {
    completion = cmp.config.window.bordered(),
    documentation = cmp.config.window.bordered(),
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-q>'] = cmp.mapping.abort(),
    ['<CR>'] = cmp.mapping.confirm({ select = true }),
  }),
  sources = cmp.config.sources({ { name = 'nvim_lsp' } })
})

local capabilities = require('cmp_nvim_lsp').default_capabilities()

require('lspconfig').rust_analyzer.setup{
  capabilities = capabilities,
}
require('lspconfig').gopls.setup{
  capabilities = capabilities,
}
require('lspconfig').denols.setup{
  capabilities = capabilities,
}
require('lspconfig').lua_ls.setup {
  capabilities = capabilities,
}
require('lspconfig').jsonls.setup {
  capabilities = capabilities,
}

vim.keymap.set('n', 'gk', function()
  local on = not vim.diagnostic.config().virtual_lines
  vim.diagnostic.config({ virtual_lines = on })
end, { desc = 'toggle diagnostic virtual_lines' })

require("nvim-tree").setup {
  view = {
    signcolumn = 'no',
    float = {
      enable = true,
      open_win_config = function()
        -- From https://github.com/MarioCarrion/videos/blob/269956e913b76e6bb4ed790e4b5d25255cb1db4f/2023/01/nvim/lua/plugins/nvim-tree.lua
        local screen_w = vim.opt.columns:get()
        local screen_h = vim.opt.lines:get() - vim.opt.cmdheight:get()
        local window_w = screen_w * 0.5
        local window_h = screen_h * 0.8
        local window_w_int = math.floor(window_w)
        local window_h_int = math.floor(window_h)
        local center_x = (screen_w - window_w) / 2
        local center_y = ((vim.opt.lines:get() - window_h) / 2) - vim.opt.cmdheight:get()
        return {
          border = "rounded",
          relative = "editor",
          row = center_y,
          col = center_x,
          width = window_w_int,
          height = window_h_int,
        }
        end,
    },
    width = function()
      return math.floor(vim.opt.columns:get() * 0.5)
    end,
  },
  on_attach = function(bufnr)
    local api = require "nvim-tree.api"
    api.config.mappings.default_on_attach(bufnr)
    vim.keymap.set('n', '<c-e>', api.tree.close, { desc = "nvim-tree: close", buffer = bufnr, noremap = true, silent = true, nowait = true })
  end
}
