vim.cmd([[
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vim/vimrc
]])

require('lualine').setup{
  options = {
    theme = 'sonokai',
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
      },
      'filetype',
    },
    lualine_y = {'progress'},
    lualine_z = {'location'}
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

require'lspconfig'.rust_analyzer.setup{
  capabilities = capabilities,
}
require'lspconfig'.gopls.setup{
  capabilities = capabilities,
}
require'lspconfig'.denols.setup{
  capabilities = capabilities,
}
require'lspconfig'.lua_ls.setup {
  capabilities = capabilities,
}
