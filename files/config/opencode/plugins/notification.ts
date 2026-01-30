import type { Plugin } from "@opencode-ai/plugin"
import path from "path"

export const NotificationPlugin: Plugin = async ({ $, client, directory }) => {
  // Only enable notifications in interactive mode (TUI), not in `opencode run ...`
  const isInteractive = process.stdin.isTTY
  const dirName = path.basename(directory)

  return {
    event: async ({ event }) => {
      if (!isInteractive) return

      if (event.type === "session.idle" || event.type === "question.asked") {
        // Check if this is from the primary agent (no parentID means root session)
        const sessionID = event.properties.sessionID
        try {
          const session = await client.session.get({ path: { id: sessionID } })
          if (session.data?.parentID) {
            // This is a subagent session, skip notification
            return
          }
        } catch {
          // If we can't determine the session type, notify anyway
        }

        // Ring terminal bell
        await $`printf '\a' > /dev/tty`.quiet()

        // Send Pushover notification
        let message: string
        if (event.type === "session.idle") {
          message = `[${dirName}] OpenCode is waiting`
        } else {
          // question.asked - extract the question(s)
          const questions = event.properties.questions
          message = `[${dirName}] ${questions.map(q => q.question).join("\n")}`
        }
        await $`bash -c 'source ~/.zenv_apikey_pushover && curl -s -X POST https://api.pushover.net/1/messages.json -d token="$PUSHOVER_TOKEN" -d user="$PUSHOVER_USER" -d "message=${message}"'`.quiet().nothrow()
      }
    },
  }
}
