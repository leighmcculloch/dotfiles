-- Helper functions for global mini.diff overlay mode
local function apply_mode_to_buffer(bufnr, mode)
  local MiniDiff = require("mini.diff")
  local buf_data = MiniDiff.get_buf_data(bufnr)
  if not buf_data then
    return
  end

  if mode == "workdir" then
    -- Restore index reference by re-enabling
    if vim.b[bufnr].minidiff_is_staged then
      MiniDiff.disable(bufnr)
      MiniDiff.enable(bufnr)
      vim.b[bufnr].minidiff_is_staged = false
    end
    -- Ensure overlay is on
    buf_data = MiniDiff.get_buf_data(bufnr)
    if buf_data and not buf_data.overlay then
      MiniDiff.toggle_overlay(bufnr)
    end
  elseif mode == "staged" then
    -- Set reference to HEAD
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    if filepath == "" then
      return
    end
    local rel_path = vim.fn.fnamemodify(filepath, ":~:.")
    local head_content = vim.fn.system({ "git", "show", "HEAD:" .. rel_path })
    if vim.v.shell_error == 0 then
      vim.b[bufnr].minidiff_is_staged = true
      MiniDiff.set_ref_text(bufnr, head_content)
      -- Ensure overlay is on
      buf_data = MiniDiff.get_buf_data(bufnr)
      if buf_data and not buf_data.overlay then
        MiniDiff.toggle_overlay(bufnr)
      end
    end
  else
    -- mode is nil, turn off overlay and restore
    if vim.b[bufnr].minidiff_is_staged then
      MiniDiff.disable(bufnr)
      MiniDiff.enable(bufnr)
      vim.b[bufnr].minidiff_is_staged = false
    end
    buf_data = MiniDiff.get_buf_data(bufnr)
    if buf_data and buf_data.overlay then
      MiniDiff.toggle_overlay(bufnr)
    end
  end
end

local function apply_mode_to_all_buffers(mode)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
      apply_mode_to_buffer(bufnr, mode)
    end
  end
end

local function set_global_mode(mode)
  vim.g.minidiff_overlay_mode = mode
  apply_mode_to_all_buffers(mode)
end

return {
  {
    "echasnovski/mini.diff",
    config = function(_, opts)
      require("mini.diff").setup(opts)

      -- Apply global mode to new buffers
      vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("MiniDiffGlobalOverlay", { clear = true }),
        callback = function(args)
          local mode = vim.g.minidiff_overlay_mode
          if mode and vim.bo[args.buf].buftype == "" then
            -- Delay to let mini.diff attach first
            vim.defer_fn(function()
              if vim.api.nvim_buf_is_valid(args.buf) then
                apply_mode_to_buffer(args.buf, mode)
              end
            end, 100)
          end
        end,
      })
    end,
    keys = {
      {
        "<leader>go",
        function()
          local mode = vim.g.minidiff_overlay_mode
          if mode == "workdir" then
            -- Already in workdir mode -> turn off
            set_global_mode(nil)
          else
            -- Switch to workdir mode
            set_global_mode("workdir")
          end
        end,
        desc = "Toggle mini.diff overlay (working dir)",
      },
      {
        "<leader>gO",
        function()
          local mode = vim.g.minidiff_overlay_mode
          if mode == "staged" then
            -- Already in staged mode -> turn off
            set_global_mode(nil)
          else
            -- Switch to staged mode
            set_global_mode("staged")
          end
        end,
        desc = "Toggle mini.diff overlay (staged/HEAD)",
      },
    },
  },
}
