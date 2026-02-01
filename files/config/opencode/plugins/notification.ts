import type { Plugin } from "@opencode-ai/plugin"
import path from "path"

export const NotificationPlugin: Plugin = async ({ $, client, directory }) => {
  const dirName = path.basename(directory)

  return {
    event: async ({ event }) => {
      
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
        let message: string | undefined
        if (event.type === "session.idle") {
          // Get the last assistant message for context
          let lastResponse = ""
          try {
            const messagesResponse = await client.session.messages({ 
              path: { id: sessionID }
            })
            
            if (messagesResponse.data) {
              const lastAssistant = [...messagesResponse.data]
                .reverse()
                .find(m => m.info.role === "assistant")
              
              if (lastAssistant) {
                const fullText = lastAssistant.parts
                  .filter(p => p.type === "text")
                  .map(p => (p as { type: "text", text: string }).text)
                  .join("\n")
                
                // Get the last non-empty line (often contains a question or next step)
                const lines = fullText.split("\n").filter(line => line.trim())
                lastResponse = (lines[lines.length - 1] || "").slice(0, 200)
              }
            }
          } catch {
            // If we can't get messages, continue without the response text
          }
          
          message = lastResponse 
            ? `[${dirName}] ${lastResponse}`
            : `[${dirName}] OpenCode is waiting`
        } else if (event.type === "question.asked") {
          // question.asked - extract the question(s)
          const questions = event.properties.questions
          message = `[${dirName}] ${questions.map(q => q.question).join("\n")}`
        }
        if (message) {
          await $`bash -c 'source ~/.zenv_apikey_pushover && curl -s -X POST https://api.pushover.net/1/messages.json -d token="$PUSHOVER_TOKEN" -d user="$PUSHOVER_USER" -d "message=${message}"'`.quiet().nothrow()
        }
      }
    },
  }
}
