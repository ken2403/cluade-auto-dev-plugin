# Auto Dev Plugin (ad)

A hierarchical multi-agent system that autonomously develops from vague instructions.

## Overview

Simply give a vague instruction like "improve authentication" and a group of agents organized like a company (CEO, VPs, Members) will autonomously work to handle everything from specification development to PR creation and review handling.

```
You (God)
    ↓ Vague instruction
   CEO (Interprets and coordinates)
  / | \
 VP  VP  VP (Department heads)
 |   |   |
PM  UX  Dev (Investigation & Implementation)
```

## Requirements

- **Claude Code CLI** (`claude` command available)
- **tmux** (for multi-pane management)
- **macOS** (for notification features. Works on Linux but notifications won't appear)

## Installation

### 1. Place the Plugin

Clone from GitHub. The plugin can be placed in **any directory**:

```bash
# Clone to any directory
cd /path/to/any-directory
git clone https://github.com/ken2403/claude-auto-dev-plugin.git
```

Example placement:

```
/opt/claude-plugins/
└── claude-auto-dev-plugin/    # This plugin
```

### 2. Enable the Plugin in Claude Code

#### Method A: Register as Marketplace (Recommended)

Registering the plugin as a Marketplace makes it available in any project:

```bash
# Add plugin as Marketplace
claude plugin marketplace add /path/to/claude-auto-dev-plugin

# Install the plugin
claude plugin install ad@claude-auto-dev-plugin
```

#### Method B: Specify Option at Startup

To use only in a specific session, start Claude Code with the `--plugin-dir` option:

```bash
cd your-project
claude --plugin-dir /path/to/claude-auto-dev-plugin
```

### 3. Verify Installation

```bash
# Start Claude Code
cd your-project-directory
claude

# Verify the plugin is recognized
/ad:status
```

Installation is successful if `/ad:status` works.

## Quick Start

### 1. Initialize (First Time Only)

```bash
cd your-project-directory
bash path/to/claude-auto-dev-plugin/scripts/dashboard.sh ad_init
```

A tmux session `auto-dev` will start and the Command Center (window 0) will open.

### 2. Give an Instruction

Execute the following in the Command Center:

```bash
/ad:run "Improve the authentication feature"
```

That's all it takes:
1. A new session ID is generated
2. A new tmux window is created
3. CEO starts, interprets the instruction, and summons VPs
4. You immediately return to the Command Center and can work on other things

### 3. Check Progress

```bash
/ad:status
```

You can check the status of all sessions, active agents, and progress.

### 4. Handle Escalations

When CEO needs your decision, you'll receive a **macOS notification**.

```bash
# Check escalation list
/ad:ans SESSION_ID

# Respond
/ad:ans SESSION_ID "TOTP only is fine. SMS can wait."
```

### 5. Cleanup

Delete completed sessions:

```bash
/ad:cleanup
```

## Command List

| Command | Description |
|---------|-------------|
| `/ad:run "instruction"` | Start a new session |
| `/ad:run --session ID` | Resume an existing session |
| `/ad:run` | Select and resume from interrupted sessions list |
| `/ad:status` | Show status of all sessions |
| `/ad:ans SESSION_ID` | Show escalation list |
| `/ad:ans SESSION_ID "answer"` | Respond to an escalation |
| `/ad:cleanup` | Delete completed sessions and worktrees |

## Usage Examples

### Example 1: Adding a New Feature

```bash
/ad:run "Add MFA (multi-factor authentication) for users"
```

CEO automatically:
- Requests requirements investigation from VP Product
- Requests UX design from VP Design
- Requests technical investigation from VP Engineering
- Integrates and creates specification documents
- Review by QA team
- Creates PR
- Review Sentinel handles review comments automatically

### Example 2: Bug Fix

```bash
/ad:run "Fix the bug causing 500 error on the login page"
```

CEO decides:
- Summons only VP Engineering (judged as a minor fix)
- Technical investigation → Fix → QA → PR

### Example 3: Investigation Only

```bash
/ad:run "Investigate and summarize the current authentication flow"
```

CEO decides:
- Summons necessary VPs
- Compiles and reports investigation results
- Does not perform implementation

## tmux Window Structure

```
┌─────────────────────────────────────────────────────────┐
│ window 0: COMMAND CENTER                                │
│ ┌──────────┬──────────────────────────┐                 │
│ │          │                          │                 │
│ │ adwatch  │ Claude CLI (80%)         │                 │
│ │  (40%)   │  Run /ad:run here        │                 │
│ │          ├──────────────────────────┤                 │
│ │          │ Free terminal (20%)      │                 │
│ │          │  git, tests, etc.        │                 │
│ └──────────┴──────────────────────────┘                 │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ window 1: Session "Auth Improvement" (session_id: abc123)│
│ ┌────────┬────────┬────────┬────────┐                   │
│ │  CEO   │VP Prod │VP Dsgn │VP Eng  │                   │
│ │        ├────────┼────────┤        │                   │
│ │        │ PM-1   │  UX    │ Dev-1  │                   │
│ │        │ PM-2   │  IA    │ Dev-2  │                   │
│ └────────┴────────┴────────┴────────┘                   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ window 2: Session "Bug Fix" (session_id: def456)        │
│ ┌────────┬────────┐                                     │
│ │  CEO   │Builder │  ← For minor fixes, CEO directly    │
│ └────────┴────────┘    starts Builder                   │
└─────────────────────────────────────────────────────────┘
```

## Escalation

CEO only asks humans for decisions in the following cases:

| Situation | Example |
|-----------|---------|
| Instruction is too vague | "Make it better" alone doesn't clarify direction |
| VP conflicts cannot be resolved | Product and Engineering disagree |
| Major business decisions | Security policy decisions |
| Irreversible decisions | Existing data migration policy |

### Escalation Flow

```
1. CEO requests a decision
   ↓
2. macOS notification arrives (with sound)
   ↓
3. You: Check content with /ad:ans SESSION_ID
   ↓
4. You: Respond with /ad:ans SESSION_ID "answer"
   ↓
5. CEO detects the answer and continues work
```

## Directory Structure

A working directory is created for each session:

```
.auto-dev/sessions/{session_id}/
├── instruction.txt        # Your instruction
├── session.json           # Session state (for resumption)
├── blackboard/            # Inter-agent communication
│   ├── ceo-directive.json
│   ├── vp-product.json
│   ├── vp-design.json
│   ├── vp-engineering.json
│   └── ...
├── escalations/           # Escalations
│   ├── 1706234567.json
│   └── 1706234567-answer.json
├── implementation/        # Implementation work
└── pr/                    # PR related
```

## Organization Structure

### Executive Level
- **CEO**: Interprets instructions and coordinates everything. Manages VP coordination and escalation decisions

### VP (Department Heads)
- **VP Product**: Requirements definition, priority decisions
- **VP Design**: UX/UI design, design decisions
- **VP Engineering**: Technical direction, architecture, implementation coordination

### Members (Summoned by VPs as needed)
- **PM-1, PM-2**: User needs research, scope analysis
- **UX, IA**: Interaction design, information architecture
- **Dev-1, Dev-2**: Codebase investigation, technical analysis
- **Builder** (N instances): Actual code implementation

### Specialist Teams
- **QA Lead**: Quality audit coordination (always summons 2+ QA members)
  - QA-Security: Security audit
  - QA-Performance: Performance audit
  - QA-Documentation: Documentation audit
- **DevOps Lead**: Worktree management, builds, PR creation
- **Review Sentinel**: Automatic monitoring and handling of PR review comments

## Tips for Instructions

### Good Instructions

```bash
# Clear purpose
/ad:run "Add a feature that allows users to reset their password when forgotten"

# Communicate constraints if any
/ad:run "Improve the login screen design. However, maintain the existing color scheme"

# When you only want investigation
/ad:run "Compile a list of current API endpoints and authentication methods (no implementation needed)"
```

### Instructions That Trouble CEO

```bash
# Too vague (may result in escalation)
/ad:run "Make it better"

# Contradictory
/ad:run "Make it faster. But don't change a single line of code"
```

## Troubleshooting

### Session Appears to Be Stuck

```bash
# Check status
/ad:status

# Switch to the relevant window and check CEO pane
tmux select-window -t auto-dev:1
```

### Missed an Escalation

```bash
# Check escalations for all sessions
/ad:ans SESSION_ID
```

### Want to Start Over

```bash
# Cleanup session and re-run
/ad:cleanup
/ad:run "instruction"
```

## Notes

- **tmux is required**: This plugin uses tmux
- **Operate from Command Center**: Always run `/ad:run` from window 0 (Command Center)
- **Respond to escalations**: Answer CEO's questions with `/ad:ans`
- **Parallel execution possible**: Multiple sessions can run simultaneously

## Script List

| Script | Purpose |
|--------|---------|
| `dashboard.sh ad_init` | Initialize tmux session |
| `adwatch.sh` | Cross-session monitor |
| `adlog.sh` | Display agent logs |
| `spinup.sh` | Start agents (internal use) |
| `teardown.sh` | Cleanup (internal use) |
| `escalate.sh` | Send escalation (internal use) |
| `notify.sh` | macOS notification (internal use) |

## License

MIT License
