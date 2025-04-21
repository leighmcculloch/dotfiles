if true then
  return {}
end
return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    opts = {
      auto_insert_mode = false,

      agent = "copilot",

      --model = "claude-3.7-sonnet",
      --model = "gpt-4.1",
      model = "gemini-2.5-pro",
    },
  },
}
