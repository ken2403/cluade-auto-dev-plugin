# Common Rules

All roles MUST follow these rules. This file is automatically prepended to every role's system prompt by `spinup.sh`.

## Session Context

When you are spawned, your initial prompt contains:
- **Working directory**: `.auto-dev/sessions/{session_id}/` — extract the session ID from this path
- **Report to**: the blackboard JSON path where you must write your report

To get the session ID in bash:
```bash
# Extract from your working directory path
SESSION_ID="<extract from the Working directory in your initial prompt>"
```

## Main Branch Protection (Absolute Rule)

- File changes on the main branch are **strictly prohibited**
- Investigation phase (Read/Grep/Glob only) is allowed on main
- **Code, tests, documentation, README, config files, API specs, comments** — creation, editing, or deletion of ANY file in the repository must be done in a Worktree
- "It's just documentation" or "It's just a README" or "It's just comments" is not an excuse. Everything requires a Worktree
- If violated, stop work immediately and escalate to your superior

## Worktree Requirement Table

| Work Type | Worktree Required? |
|-----------|-------------------|
| Code investigation/analysis only | No |
| Design/spec planning (blackboard records) | No |
| **Changing even 1 line of code** | **Yes** |
| **Adding/deleting files** | **Yes** |
| **Changing config files** | **Yes** |
| **Adding/modifying tests** | **Yes** |
| **Updating README.md** | **Yes** |
| **Adding/changing docs/** | **Yes** |
| **Updating API specs** | **Yes** |
| **Adding/modifying comments** | **Yes** |

## Polling Rules

- Use **fixed 10-second intervals** when waiting for reports. **No exponential backoff.**
- Never increase the wait interval between checks.
- If a report hasn't arrived, keep checking at the same interval until timeout.

## Pane Cleanup

After reading and integrating a subordinate's report, **close their pane immediately**.

Replace `WINDOW_INDEX` with the tmux window number (from your initial prompt or `tmux list-windows`) and `PANE_TITLE` with the subordinate's role name (e.g., `pm-1`, `dev-2`, `qa-security`):

```bash
TMUX_SESSION=$(cat .auto-dev/tmux-session)
# Find and close a specific subordinate's pane by title
tmux list-panes -t "$TMUX_SESSION:WINDOW_INDEX" -F '#{pane_index}|#{pane_title}' | \
  grep "PANE_TITLE" | cut -d'|' -f1 | \
  xargs -I{} tmux kill-pane -t "$TMUX_SESSION:WINDOW_INDEX.{}"
```

**Example**: To close the `pm-1` pane in window 2:
```bash
TMUX_SESSION=$(cat .auto-dev/tmux-session)
tmux list-panes -t "$TMUX_SESSION:2" -F '#{pane_index}|#{pane_title}' | \
  grep "pm-1" | cut -d'|' -f1 | \
  xargs -I{} tmux kill-pane -t "$TMUX_SESSION:2.{}"
```

Do not leave finished panes open. Close them as soon as their report is consumed.

## File Cleanup

After integrating subordinate reports, you **may delete** the report files.

- Delete consumed report files from `blackboard/` (e.g., `blackboard/dev-1.json`)
- If you want to keep history, move files to `blackboard/archive/`

## Subagent Tool Invocation

Subagents are invoked via the **Task tool** (Claude's built-in tool for spawning sub-processes). They are NOT bash scripts.

### How to call a subagent

Use the Task tool with the agent's name as `subagent_type` and a descriptive prompt:

| Subagent | Purpose | Example prompt |
|----------|---------|----------------|
| `blackboard-watcher` | Wait for blackboard JSON files to appear | `"Watch for reports in .auto-dev/sessions/ID/blackboard/: Expected files: vp-product.json, vp-design.json. Timeout: 600 seconds. Check interval: 10 seconds"` |
| `pane-watcher` | Monitor tmux pane output for completion/errors | `"Monitor pane auto-dev:1.2 for completion. Success patterns: 'Report written to'. Error patterns: 'Error:'. Timeout: 300 seconds"` |
| `codebase-explorer` | Explore codebase structure and patterns | `"Explore the authentication implementation. Where is auth logic? What patterns are used?"` |
| `code-analyzer` | Analyze code quality, security, dependencies | `"Analyze security of src/auth/*.ts. Check: injection, XSS, hardcoded secrets"` |
| `test-runner` | Execute and analyze tests | `"Run tests in worktrees/ID-impl. Report pass/fail and coverage"` |
| `git-operator` | Manage worktrees, branches, commits | `"Create worktree at worktrees/ID-impl from main branch"` |
| `doc-writer` | Generate specs and documentation | `"Write API documentation for src/api/users.ts"` |

### Important notes

- **blackboard-watcher**: Use fixed 10-second check intervals. Never use exponential backoff.
- **pane-watcher**: Read-only. It never sends input to panes.
- All subagents return their results as the Task tool's return value — read the result directly.
