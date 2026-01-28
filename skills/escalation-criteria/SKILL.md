# Escalation Criteria Skill

Determine when to escalate decisions to a higher authority.

## Purpose

This skill helps all agents decide whether to:
1. Handle a situation themselves
2. Escalate to their direct supervisor
3. Escalate all the way to God (Human)

## Escalation Hierarchy

```
God (Human)
    ↑ Only escalate: irreversible, security, major scope, unclear direction
CEO
    ↑ Only escalate: cross-department, can't resolve VP conflict
VP (Product/Design/Engineering)
    ↑ Only escalate: beyond scope, cross-team impact
Member (PM/UX/IA/Dev) / Specialist (QA/Builder)
```

## Decision Framework

### Step 1: Classify the Decision

| Classification | Description |
|---------------|-------------|
| Routine | Standard work within your defined responsibilities |
| Judgment Call | Requires interpretation but within your authority |
| Policy | Sets precedent or affects how things are done |
| Strategic | Affects direction, resources, or priorities |
| Irreversible | Cannot be easily undone once made |
| Security | Has security or compliance implications |

### Step 2: Apply the Matrix

| Classification | Member | VP | CEO | God |
|---------------|--------|-----|-----|-----|
| Routine | ✅ Decide | ✅ Decide | ✅ Decide | N/A |
| Judgment Call | ✅ Decide | ✅ Decide | ✅ Decide | N/A |
| Policy | ⬆️ Escalate | ✅ Decide | ✅ Decide | N/A |
| Strategic | ⬆️ Escalate | ⬆️ Escalate | ✅ Decide | Sometimes |
| Irreversible | ⬆️ Escalate | ⬆️ Escalate | ⬆️ Escalate | ✅ Decide |
| Security | ⬆️ Escalate | ⬆️ Escalate | ⬆️ Escalate | ✅ Decide |

## When to Escalate: Quick Reference

### Member → VP
- Task is outside your defined scope
- You lack information to decide
- Decision affects other team members
- Conflicting requirements discovered
- Blocked by something you can't control

### VP → CEO
- Cross-department impact (Product vs Engineering)
- Can't resolve conflict with peer VP
- Major technical debt or risk discovered
- Significant timeline impact
- Resource constraint issues

### CEO → God
- Instruction is too vague to interpret confidently
- Irreversible decision (delete data, security choice)
- Major scope change from original request
- Security vulnerability with business implications
- VPs fundamentally disagree and CEO can't resolve

## When NOT to Escalate

### Don't Escalate If:
- You have the authority to decide
- It's a standard part of your role
- You can make a reasonable judgment call
- It's not time-sensitive and you can research more
- You're just seeking validation (decide and report)

### Anti-Patterns to Avoid

❌ **Rubber-stamping**: Escalating every decision to avoid responsibility
❌ **Vague escalation**: "What should I do?" without analysis
❌ **Premature escalation**: Escalating before gathering relevant info
❌ **Fear-based escalation**: Escalating because uncertain, not because truly stuck

## Escalation Format

When you do escalate, include:

```json
{
  "escalation_type": "decision_needed",
  "from": "your-role",
  "to": "supervisor-role",
  "summary": "Brief summary (one line)",
  "context": {
    "situation": "What happened",
    "analysis": "What you've determined",
    "constraints": "What limits options"
  },
  "options": [
    {
      "option": "A",
      "description": "What option A entails",
      "pros": ["advantages"],
      "cons": ["disadvantages"],
      "risk": "low|medium|high"
    }
  ],
  "recommendation": "What you suggest if you have one",
  "urgency": "high|medium|low",
  "deadline": "When decision is needed by (if applicable)"
}
```

## Examples

### ✅ Good Escalation (PM → VP Product)
```
Summary: Requirements conflict - OAuth and session-based auth both requested
Analysis: Marketing wants OAuth for social features, Security wants session-based for control
Options:
  A: OAuth only (simpler, marketing happy, security concern)
  B: Session only (secure, limits social features)
  C: Both (complex, longer timeline)
Recommendation: Option C with phased rollout
```

### ❌ Bad Escalation (PM → VP Product)
```
Summary: Not sure what to do about auth
[No analysis, no options, no recommendation]
```

### ✅ Good Decision (Stay at PM level)
```
Situation: User story needs clarification on edge case
Decision: Assume standard behavior, document assumption, proceed
Rationale: This is within normal PM judgment, not policy-setting
```

## Role-Specific Guidance

### For Members (PM/UX/IA/Dev)
Your authority: Investigation, analysis, recommendations within your domain
Escalate: Cross-domain impact, conflicting requirements, blocked work

### For VPs
Your authority: Department direction, team coordination, member conflicts
Escalate: Cross-department issues, major risks, resource constraints

### For QA Team
Your authority: Quality assessment, approve/reject based on criteria
Escalate: Unclear criteria, security concerns, fix vs ship tradeoffs

### For CEO
Your authority: VP coordination, standard execution, conflict resolution
Escalate to God: Unclear direction, irreversible choices, security, major scope
