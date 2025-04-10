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
      quit_on_focus_loss = true,
      open_win_config = {
        relative = "editor",
        border = "rounded",
        width = 30,
        height = 30,
        row = 2,
        col = 3,
      },
    },
  },
  on_attach = function(bufnr)
    local api = require "nvim-tree.api"
    api.config.mappings.default_on_attach(bufnr)
    vim.keymap.set('n', '<c-e>', api.tree.close, { desc = "nvim-tree: close", buffer = bufnr, noremap = true, silent = true, nowait = true })
  end
}
