import type { Plugin } from "@opencode-ai/plugin"
import path from "path"

async function log(...args) {
  await import("fs/promises").then(fs=>fs.appendFile("log.txt", "⭐️ " + [...args].map(String).join(' ')+"\n"));
}

export const NotificationPlugin: Plugin = async ({ $, client, directory }) => {
  await log("plugin start")
  const isInteractive = process.stdin.isTTY
  const dirName = path.basename(directory)

  return {
    event: async ({ event }) => {
      
      await log("plugin event:", JSON.stringify(event))
      //if (!isInteractive) return

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
        if (isInteractive) {
          await log("plugin event: print \\a")
          await $`printf '\a' > /dev/tty`.quiet()
          await log("plugin event: printed \\a")
        }

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
