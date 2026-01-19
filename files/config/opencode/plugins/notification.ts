import type { Plugin } from "@opencode-ai/plugin"

export const NotificationPlugin: Plugin = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        // Ring terminal bell
        await $`printf '\a' > /dev/tty`.quiet()

        // Send Pushover notification
        await $`source ~/.zenv_apikey_pushover && curl -s -X POST https://api.pushover.net/1/messages.json -d token="$PUSHOVER_TOKEN" -d user="$PUSHOVER_USER" -d "message=[opencode] Session completed"`.quiet().nothrow()
      }
    },
  }
}
