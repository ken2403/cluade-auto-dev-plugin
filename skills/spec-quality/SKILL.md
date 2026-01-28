# Spec Quality Skill

Evaluate the quality and completeness of feature specifications.

## Purpose

This skill helps VP Product and QA Lead evaluate whether a feature specification is ready for implementation.

## Usage

Use this skill to check if a spec meets quality standards before proceeding to implementation.

## Quality Criteria

### Completeness Checklist

#### Problem Statement
- [ ] Clear description of the problem being solved
- [ ] Who is affected (user personas)
- [ ] Why it matters (business impact)

#### Requirements
- [ ] Functional requirements listed
- [ ] Non-functional requirements listed
- [ ] Each requirement has priority (must/should/could)
- [ ] Requirements are testable

#### User Stories
- [ ] Follow "As a [user], I want [action], so that [benefit]" format
- [ ] Each has acceptance criteria
- [ ] Acceptance criteria are testable
- [ ] Edge cases considered

#### Technical Design
- [ ] Architecture approach described
- [ ] Files to modify/create listed
- [ ] Patterns to follow identified
- [ ] Dependencies noted
- [ ] Performance considerations addressed

#### Testing Plan
- [ ] Unit test scope defined
- [ ] Integration test scope defined
- [ ] Manual test scenarios listed

#### Risks & Mitigations
- [ ] Risks identified
- [ ] Each risk has mitigation strategy
- [ ] Rollback plan exists

### Scoring

| Score | Meaning | Action |
|-------|---------|--------|
| 90-100% | Excellent | Ready for implementation |
| 70-89% | Good | Minor improvements, can proceed |
| 50-69% | Fair | Needs work before proceeding |
| <50% | Poor | Major revision needed |

## Evaluation Template

```json
{
  "spec_path": "docs/features/feature-name.md",
  "evaluation": {
    "problem_statement": {
      "score": 8,
      "max": 10,
      "issues": []
    },
    "requirements": {
      "score": 7,
      "max": 10,
      "issues": ["Missing priority on NFR-2"]
    },
    "user_stories": {
      "score": 9,
      "max": 10,
      "issues": []
    },
    "technical_design": {
      "score": 6,
      "max": 10,
      "issues": ["Dependencies not fully mapped"]
    },
    "testing_plan": {
      "score": 8,
      "max": 10,
      "issues": []
    },
    "risks": {
      "score": 5,
      "max": 10,
      "issues": ["Missing rollback plan"]
    }
  },
  "total_score": 43,
  "max_score": 60,
  "percentage": 72,
  "verdict": "Good - minor improvements needed",
  "blocking_issues": ["Missing rollback plan"],
  "recommendations": [
    "Add rollback plan",
    "Complete dependency mapping",
    "Add priority to NFR-2"
  ]
}
```

## Quick Check Questions

1. Could a developer implement this without asking questions?
2. Could QA write test cases from this spec?
3. Are all edge cases documented?
4. Is the scope clearly defined (what's in vs out)?
5. Are success metrics measurable?

## Common Issues

### Vague Requirements
❌ "System should be fast"
✅ "Page load time should be under 200ms on 3G connection"

### Missing Acceptance Criteria
❌ "User can reset password"
✅ "Given user is on login page, when they click 'forgot password' and enter email, then reset link is sent within 1 minute"

### Incomplete Edge Cases
❌ "User can upload image"
✅ "User can upload image (max 5MB, formats: jpg/png/gif, error shown if too large)"

### No Testability
❌ "System should be secure"
✅ "All API endpoints require authentication, failed attempts return 401"
