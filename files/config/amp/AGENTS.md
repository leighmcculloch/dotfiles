# Amp Agent Guidelines

## Core Principles

**Always read before editing.** Use Read, Grep, or finder to understand existing code patterns, conventions, and structure before making changes.

**Use oracle frequently.** Consult oracle for:
- Planning complex features or refactors
- Reviewing code architecture and implementations
- Debugging tricky issues across multiple files
- Analyzing performance or security concerns

**Leverage parallel execution.** Run independent searches, reads, and analyses in parallel to maximize speed.

**Use todo_write proactively.** Break down complex tasks into tracked steps. Mark items complete as you go, not all at once.

## Code Quality

**Run diagnostics after every change.** Always run `get_diagnostics` and any build/typecheck commands after implementing changes. Fix all errors before considering a task complete.

**Match existing patterns.** Study the codebase first:
- Check imports to understand framework/library choices
- Follow existing naming conventions
- Match code style and structure
- Use established utilities and helpers

**No unnecessary comments.** Only add comments when explicitly requested or when code complexity demands it. Explanations belong in the response, not the code.

**No suppression.** Don't suppress compiler, linter, or type errors unless explicitly requested.

## Security

**Never expose secrets.** Never log, commit, or expose API keys, tokens, or credentials. Always use environment variables and proper secret management.

## Testing

**Discover, don't assume.** Never assume test frameworks or commands. Check in order:
1. Makefile - read it to discover available targets
2. This AGENTS.md file for project-specific commands
3. Language-specific files:
   - Rust: `cargo test`, `cargo build`, `cargo clippy`, `cargo fmt --check`
   - Go: `go test ./...`, `go build ./...`, `go vet ./...`
   - Deno: check deno.json/deno.jsonc for tasks, or `deno test`, `deno check`
4. Existing test files for patterns and frameworks in use

**Write comprehensive tests.** Study existing tests first, then write tests that match the project's patterns and provide good coverage.

## Development Workflow

**Check for commands in this order:**
1. Makefile - read it to discover available targets
2. Language-specific defaults:
   - Rust: `cargo test && cargo clippy`
   - Go: `go test ./... && go vet ./...`
   - Deno: `deno task test` or `deno test && deno check`
3. Document discovered commands below for future reference

## Communication

**Be direct and concise.** Skip flattery, get to the point, minimize token usage.

**Link to code.** Always create markdown links to files and line numbers when referencing code.

**No apologies.** If you can't do something, offer alternatives or keep responses short.

## Task Completion

**Iterate to completion.** Never ask if you should continue. Keep going until the task is fully done, all tests pass, and diagnostics are clean.

**Verify your work.** After implementing:
1. Run diagnostics
2. Run build/typecheck commands
3. Run tests if applicable
4. Fix any issues that arise

## Understanding Dependencies

**Use documentation tools proactively.** When working with external libraries or dependencies:
- Use librarian to search GitHub repositories and understand how libraries work
- Use github MCP to read code, search repos, and check issues/PRs
- Use deepwiki MCP to ask questions about GitHub repositories
- Use context7 MCP to fetch official documentation for libraries
- Use perplexity MCP to ask questions about dependencies and best practices

## MCP Servers

Use available MCP servers for extended capabilities when appropriate.
