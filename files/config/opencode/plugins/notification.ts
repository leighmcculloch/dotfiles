import type { Plugin } from "@opencode-ai/plugin"

export const NotificationPlugin: Plugin = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.idle" || event.type === "question.asked") {
        // Ring terminal bell
        await $`printf '\a' > /dev/tty`.quiet()

        // Send Pushover notification
        let message: string
        if (event.type === "session.idle") {
          message = "OpenCode is waiting"
        } else {
          // question.asked - extract the question(s)
          const questions = event.properties.questions
          message = questions.map(q => q.question).join("\n")
        }
        await $`bash -c 'source ~/.zenv_apikey_pushover && curl -s -X POST https://api.pushover.net/1/messages.json -d token="$PUSHOVER_TOKEN" -d user="$PUSHOVER_USER" -d "message=${message}"'`.quiet().nothrow()
      }
    },
  }
}
