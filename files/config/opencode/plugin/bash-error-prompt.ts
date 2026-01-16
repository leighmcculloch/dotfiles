import type { Plugin } from "@opencode-ai/plugin"

/**
 * Plugin that prompts the primary agent to engage when a bash command fails.
 *
 * When a bash tool execution returns a non-zero exit code, this plugin
 * automatically sends a follow-up message to the agent asking it to
 * investigate and fix the error.
 */
export const BashErrorPrompt: Plugin = async ({ client }) => {
  return {
    "tool.execute.after": async (input, output) => {
      // Only handle bash tool executions
      if (input.tool !== "bash") return

      // Check if the command failed (non-zero exit code)
      const exitCode = output.metadata?.exitCode
      if (exitCode !== undefined && exitCode !== 0) {
        // Append a prompt to the TUI input to engage the agent
        await client.tui.prompt.append({
          text: `The previous bash command failed with exit code ${exitCode}. Please investigate the error.`,
        })
      }
    },
  }
}
