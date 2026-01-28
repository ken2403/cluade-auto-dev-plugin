# {Feature Name}

> Session: {session_id}
> Created: {date}
> Status: Draft | Review | Approved

## Overview

Brief description of the feature and why it's being built.

### Problem Statement

What problem does this solve? Who is affected?

### Goals

- Goal 1
- Goal 2

### Non-Goals (Out of Scope)

- What this feature does NOT include
- Explicitly excluded functionality

## User Stories

### US-001: {Story Title}

**As a** {user type}
**I want to** {action}
**So that** {benefit}

**Acceptance Criteria:**
- [ ] Given {context}, when {action}, then {expected result}
- [ ] Given {context}, when {action}, then {expected result}

**Priority:** Must | Should | Could

---

### US-002: {Story Title}

...

## Requirements

### Functional Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| FR-001 | {requirement} | Must | |
| FR-002 | {requirement} | Should | |

### Non-Functional Requirements

| ID | Requirement | Priority | Notes |
|----|-------------|----------|-------|
| NFR-001 | {requirement} | Must | |
| NFR-002 | {requirement} | Should | |

## Technical Design

### Architecture

High-level architecture description or diagram.

### Data Model Changes

```
{schema changes or "No changes"}
```

### API Changes

#### New Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /api/... | ... |

#### Modified Endpoints

| Method | Path | Changes |
|--------|------|---------|
| GET | /api/... | Added field X |

### Files to Modify

- `src/path/file.ts` - {what changes}
- `src/path/file.ts` - {what changes}

### Files to Create

- `src/path/new-file.ts` - {purpose}
- `tests/path/new-file.test.ts` - {purpose}

### Patterns to Follow

- Pattern 1: {reference location}
- Pattern 2: {reference location}

### Dependencies

- {package} - {why needed}
- {external service} - {why needed}

## UX Design

### User Flow

1. User does X
2. System shows Y
3. User does Z
4. System responds with W

### Wireframes / Mockups

{Link to designs or description}

### Feedback States

- **Success:** {how to show success}
- **Error:** {how to show errors}
- **Loading:** {how to show loading}
- **Empty:** {how to show empty state}

## Testing Plan

### Unit Tests

- [ ] {test case 1}
- [ ] {test case 2}

### Integration Tests

- [ ] {test case 1}
- [ ] {test case 2}

### Manual Test Scenarios

1. **Scenario:** {description}
   - Steps: ...
   - Expected: ...

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| {risk} | High/Med/Low | High/Med/Low | {mitigation} |

## Rollback Plan

If issues arise after deployment:
1. {step 1}
2. {step 2}

## Success Metrics

| Metric | Target | How to Measure |
|--------|--------|----------------|
| {metric} | {target} | {measurement method} |

## Timeline

| Phase | Description | Duration |
|-------|-------------|----------|
| Implementation | ... | ... |
| QA | ... | ... |
| Rollout | ... | ... |

---

## Appendix

### Related Documents

- {link to related spec}
- {link to design doc}

### Revision History

| Date | Author | Changes |
|------|--------|---------|
| {date} | {author} | Initial draft |
