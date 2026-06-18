#!/usr/bin/env zsh

# Shared by the SessionStart and Stop hooks. Prints this repo's commit/PR/branch
# workflow rules as a JSON-escaped string (with no surrounding quotes) so each hook
# can splice it into its own JSON output: SessionStart into additionalContext, Stop
# into the block reason. The rules and the escaping live here so there is one copy.

set -o errexit
set -o pipefail
set -o nounset

# the rules as plain multi-line text. kept free of " and \ so the escaping below
# only has to turn newlines and tabs into their JSON escape sequences.
rules=$(cat <<'EOF'
Workflow rules for this repo (claude-cloud):
- Commits: create every commit with the /commit skill, never a raw git commit. Never add a Co-Authored-By: Claude or a Claude-Session trailer.
- Pull requests: create every PR with the /pr skill.
- Branches: create every new branch with the /branch skill. If the current branch is named claude/..., the first action in the workflow is to run /branch to rename it without the claude/ prefix.
EOF
)

# JSON-escape: backslash and double quote first (defensive, the text avoids them),
# then tabs and newlines into \t and \n.
rules=${rules//\\/\\\\}
rules=${rules//\"/\\\"}
rules=${rules//$'\t'/\\t}
rules=${rules//$'\n'/\\n}

print -rn -- "$rules"
