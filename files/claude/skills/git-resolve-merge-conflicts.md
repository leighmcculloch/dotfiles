# Resolve Merge Conflicts

This skill resolves git merge conflicts in the current repository.

## When to use

Use this skill when:
- The user asks to "resolve merge conflicts"
- The user mentions "merge conflict" or "conflict markers"
- There are unmerged files in the git repository

## Instructions

There are git merge conflicts in this repository. Find the conflicted files, analyze the conflicts, and resolve them by editing the files to remove the conflict markers and merge the changes appropriately.

Steps:
1. Run `git diff --name-only --diff-filter=U` to find files with conflicts
2. Read each conflicted file to understand the conflict markers (`<<<<<<< HEAD`, `=======`, `>>>>>>> branch`)
3. Analyze both versions of the conflicted code
4. Edit each file to resolve the conflict by:
   - Intelligently merging both changes where possible
   - Choosing the most appropriate version when changes are incompatible
   - Preserving all necessary code from both sides
   - Removing all conflict markers
5. Stage the resolved files with `git add`
