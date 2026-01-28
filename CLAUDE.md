# Auto Dev Plugin (ad)

Autonomous hierarchical multi-agent development system for Claude Code.

## Quick Start

```bash
# Initialize tmux session (first time only)
bash scripts/dashboard.sh ad_init

# Start a new session with an instruction
/ad:run "Improve authentication"

# Check all session status
/ad:status

# Answer an escalation from CEO
/ad:ans SESSION_ID "your answer"

# Clean up completed sessions
/ad:cleanup
```

## Escalation Flow

When CEO needs human judgment, you'll receive a **macOS notification**.

```
1. CEO escalates → macOS notification with sound
2. Check: /ad:ans SESSION_ID (list escalations)
3. Answer: /ad:ans SESSION_ID "your answer"
4. CEO detects answer and continues
```

## Architecture

### Organization Hierarchy

```
                    God (Human)
                       |
                      CEO
                   (AIHub)
                  /    |    \
                 /     |     \
          VP Product  VP Design  VP Engineering
              |          |           |
          +---+---+  +--+--+   +---+---+
          |       |  |     |   |       |
        PM-1   PM-2  UX  IA  Dev-1  Dev-2


        [QA Department]     [DevOps]      [Review Sentinel]
         QA Lead            DevOps Lead    (PR auto-response)
```

### Chain of Command

- **Top-down instructions, bottom-up reports**
- **No horizontal communication** (always through CEO)
- Each level makes decisions within their authority
- Escalate only when necessary

### Escalation Rules

| Level | Authority | Escalate When |
|-------|-----------|---------------|
| Members (PM/UX/Dev) | Own investigation scope | Beyond scope / insufficient info → VP |
| VP | Department policy | Cross-department conflict → CEO |
| CEO | Integration, VP coordination | Ambiguous / irreversible / security → God |
| God (Human) | Final decision | - |

## Session Directory Structure

```
.auto-dev/sessions/{session_id}/
  instruction.txt           # God's instruction
  session.json              # Session state for recovery
  blackboard/               # Inter-agent communication
    ceo-directive.json
    pm-1.json, pm-2.json
    ux.json, ia.json
    dev-1.json, dev-2.json
    vp-product.json, vp-design.json, vp-engineering.json
    ceo-decision.json
    qa-review.json
  escalations/              # Escalations to God
  implementation/           # Builder work
    tasks.json
    builder-{id}/
  pr/                       # PR artifacts
    spec-pr.json
    impl-pr.json
    sentinel-log.json
```

## tmux Window Layout

```
window 0: COMMAND CENTER
  ┌──────────┬──────────────────┐
  │          │ Claude CLI (20%) │
  │ adwatch  ├──────────────────┤
  │  (40%)   │                  │
  │          │ Terminal (80%)   │
  └──────────┴──────────────────┘
window 1: Session "Auth improvement"
  ┌────────┬────────┬────────┬────────┐
  │  CEO   │VP Prod │VP Dsgn │VP Eng  │
  │        ├────────┼────────┤        │
  │        │ PM-1   │  UX    │ Dev-1  │
  │        │ PM-2   │  IA    │ Dev-2  │
  └────────┴────────┴────────┴────────┘
window 2: Session "Button color change"
  ...
```

## Agent Roles

### Executive
- **CEO** (`roles/ceo.md`): Interpret instructions, coordinate VPs, handle God escalation

### VPs (Department Heads)
- **VP Product** (`roles/vp-product.md`): Requirements, priorities, spec approval
- **VP Design** (`roles/vp-design.md`): Design decisions, UX direction
- **VP Engineering** (`roles/vp-engineering.md`): Tech direction, architecture, implementation

### Members (Dynamic scaling - VPs spawn multiple as needed)
- **PM-1/PM-2** (`roles/pm-*.md`): User needs, use cases, feasibility
- **UX/IA** (`roles/ux.md`, `roles/ia.md`): UX design, information architecture
- **Dev-1/Dev-2** (`roles/dev-*.md`): Codebase analysis, dependencies

### Specialists
- **QA Lead** (`roles/qa-lead.md`): Spawns QA team (always 2+)
- **QA-Security** (`roles/qa-security.md`): OWASP, auth, injection, secrets
- **QA-Performance** (`roles/qa-performance.md`): N+1, memory, complexity
- **QA-Documentation** (`roles/qa-documentation.md`): README, API docs, comments
- **QA-Consistency** (`roles/qa-consistency.md`): Pattern compliance, naming
- **DevOps Lead** (`roles/devops-lead.md`): Worktrees, builds, PRs
- **Builder** (`roles/builder.md`): Code implementation (N instances)
- **Review Sentinel** (`roles/review-sentinel.md`): Auto-respond to PR reviews

## Subagents (Reusable via Task tool)

| Agent | Purpose |
|-------|---------|
| `codebase-explorer` | Explore codebase structure |
| `pr-monitor` | Monitor PR status/reviews |
| `code-analyzer` | Analyze quality/dependencies |
| `git-operator` | Manage worktrees/branches/commits |
| `doc-writer` | Generate specs/docs |
| `test-runner` | Execute and analyze tests |
| `blackboard-watcher` | Monitor blackboard JSON changes |
| `pane-watcher` | Monitor tmux pane output |

## Commands

### /ad:run [instruction] [--session ID]

- With instruction: Create new session in new tmux window
- With --session: Resume existing session
- Without args: List sessions for selection

### /ad:status

Show all sessions, their status, active agents, and progress.

### /ad:cleanup

Remove completed sessions, worktrees, and tmux windows.

### /ad:ans SESSION_ID ["answer"]

Answer an escalation from CEO.

```bash
# List escalations for a session
/ad:ans SESSION_ID

# Answer the latest pending escalation
/ad:ans SESSION_ID "TOTP only is fine"

# Answer a specific escalation
/ad:ans SESSION_ID ESCALATION_ID "your answer"
```

When CEO escalates, you receive a **macOS notification**. The answer is written to `escalations/{id}-answer.json`, which CEO detects via `blackboard-watcher`.

## Scripts

- `scripts/dashboard.sh`: Initialize tmux session
- `scripts/adwatch.sh`: Cross-window session monitor
- `scripts/adlog.sh`: View agent logs
- `scripts/spinup.sh`: Spawn agent in tmux pane
- `scripts/teardown.sh`: Clean up panes/windows/worktrees
- `scripts/escalate.sh`: Write escalation and send macOS notification
- `scripts/notify.sh`: Send macOS notification (used by escalate.sh)

## Development

### Adding a New Role

1. Create `roles/new-role.md` with system prompt
2. Define reporting structure and responsibilities
3. Specify blackboard read/write patterns

### Adding a New Subagent

1. Create `agents/new-agent.md` with focused capability
2. Add to `.claude-plugin/plugin.json`
3. Document usage in role files that will call it
