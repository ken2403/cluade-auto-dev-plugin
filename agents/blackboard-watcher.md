# Blackboard Watcher Agent

Specialized agent for monitoring blackboard JSON files and detecting changes.

## Purpose

Watch for file appearances, updates, and completions in the blackboard directory. Used by CEOs, VPs, and other supervisors to monitor subordinate reports.

## Capabilities

- File existence checking
- File modification detection
- Content validation
- Multi-file monitoring
- Timeout handling

## Usage

Called via Task tool by CEO, VPs, and QA Lead to wait for subordinate reports.

## Input Format

### Wait for Specific Files
```
Watch for reports in .auto-dev/sessions/abc123/blackboard/:
- Expected files: pm-1.json, pm-2.json
- Timeout: 300 seconds
- Check interval: 5 seconds
```

### Monitor for Any Changes
```
Monitor .auto-dev/sessions/abc123/blackboard/ for any new files:
- Duration: 60 seconds
- Report new files immediately
```

### Validate Content
```
Wait for .auto-dev/sessions/abc123/blackboard/vp-product.json:
- Validate: has 'status' field = 'complete'
- Timeout: 180 seconds
```

## Output Format

### Files Found
```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "type": "watch_complete",
  "directory": ".auto-dev/sessions/abc123/blackboard",
  "status": "all_found",
  "expected": ["pm-1.json", "pm-2.json"],
  "found": [
    {
      "file": "pm-1.json",
      "found_at": "2024-01-01T11:58:30Z",
      "size_bytes": 2048,
      "valid": true
    },
    {
      "file": "pm-2.json",
      "found_at": "2024-01-01T11:59:15Z",
      "size_bytes": 1856,
      "valid": true
    }
  ],
  "elapsed_seconds": 75,
  "summary": "All 2 expected files found and validated"
}
```

### Timeout
```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "type": "watch_timeout",
  "directory": ".auto-dev/sessions/abc123/blackboard",
  "status": "timeout",
  "expected": ["pm-1.json", "pm-2.json", "pm-3.json"],
  "found": [
    {"file": "pm-1.json", "found_at": "2024-01-01T11:58:30Z", "valid": true},
    {"file": "pm-2.json", "found_at": "2024-01-01T11:59:15Z", "valid": true}
  ],
  "missing": ["pm-3.json"],
  "elapsed_seconds": 300,
  "summary": "Timeout: 1 of 3 expected files missing (pm-3.json)",
  "recommended_actions": [
    "Check pane status with pane-watcher to see if agent is still working",
    "Consider extending wait time if agent is active",
    "Consider re-spawning agent if pane has crashed",
    "Consider proceeding with partial data if missing report is non-critical"
  ]
}
```

**Important**: A timeout is **not a stop signal**. The caller (CEO/VP) should autonomously determine the next action by referring to `recommended_actions`.

### Change Detection
```json
{
  "timestamp": "2024-01-01T12:00:00Z",
  "type": "change_detected",
  "directory": ".auto-dev/sessions/abc123/blackboard",
  "changes": [
    {
      "file": "ceo-directive.json",
      "change_type": "created",
      "detected_at": "2024-01-01T11:55:00Z"
    },
    {
      "file": "vp-product.json",
      "change_type": "modified",
      "detected_at": "2024-01-01T11:57:30Z",
      "previous_size": 1024,
      "new_size": 2048
    }
  ]
}
```

## Validation Rules

### Basic Validation
- File exists
- File is valid JSON
- File is non-empty

### Content Validation
Can check for specific fields:
```json
{
  "validate": {
    "required_fields": ["status", "report", "timestamp"],
    "status_value": "complete",
    "min_report_length": 100
  }
}
```

## Watch Strategies

### Poll-Based (Default)
```
Check every N seconds for file existence/changes.
Simple, reliable, works everywhere.
```

### One-Shot Check
```
Check once and return immediately.
Use for quick status checks.
```

## Execution Guidelines

1. **Use efficient polling**: Don't overwhelm filesystem
2. **Validate early**: Check JSON validity when file first appears
3. **Report incrementally**: Notify as each file arrives, not just at end
4. **Handle partial success**: Some files may arrive, others timeout
5. **Clean error messages**: Clearly state what's missing and why

## Tools to Use

- `Bash`: `ls`, `stat`, file checks
- `Read`: Parse JSON files
- `Glob`: Find matching files

## Monitoring Patterns

### CEO Waiting for VPs
```
Watch: vp-product.json, vp-design.json, vp-engineering.json
Validation: status = "complete"
Timeout: 600 seconds (VPs may have complex work)
```

### VP Waiting for Members
```
Watch: pm-1.json, pm-2.json (or dev-1.json, dev-2.json)
Validation: has "findings" field
Timeout: 300 seconds
```

### QA Lead Waiting for QA Team
```
Watch: qa-security.json, qa-performance.json
Validation: has "issues" array and "approved" boolean
Timeout: 300 seconds
All must report before QA passes
```

## Example Prompts

### From CEO
```
Wait for all VP reports:
Directory: .auto-dev/sessions/abc123/blackboard/
Files: vp-product.json, vp-design.json, vp-engineering.json
Validation: all have status = "complete"
Timeout: 10 minutes
Notify me as each arrives
```

### From VP Product
```
Monitor for PM reports:
Directory: .auto-dev/sessions/abc123/blackboard/
Pattern: pm-*.json
Timeout: 5 minutes
Report when all expected PMs report
```

### From QA Lead
```
Wait for all QA team:
Files: qa-security.json, qa-performance.json, qa-documentation.json
All must have "approved" field
Report immediately if any has "approved: false"
```

## Edge Cases

### File Appears but Invalid JSON
```json
{
  "file": "pm-1.json",
  "status": "invalid",
  "error": "JSON parse error at line 15",
  "action": "File found but not valid - will retry"
}
```

### File Disappears (Deleted/Moved)
```json
{
  "file": "pm-1.json",
  "status": "disappeared",
  "last_seen": "2024-01-01T11:58:00Z",
  "action": "File was present but now missing - treating as incomplete"
}
```

### Rapid Updates
```json
{
  "file": "vp-product.json",
  "status": "updating",
  "updates_in_last_minute": 5,
  "action": "File being actively written - waiting for stable state"
}
```
