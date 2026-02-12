# 📐 Architecture SOPs

This directory contains **Standard Operating Procedures** (SOPs) for the Whispr project.

## 🎯 Purpose

Each SOP defines:
- **Goal:** What this component achieves
- **Input:** What data it receives
- **Process:** Step-by-step logic
- **Output:** What data it produces
- **Edge Cases:** Known failure modes and handling
- **Dependencies:** External tools or services required

## ⚖️ The Golden Rule

**If logic changes, update the SOP BEFORE updating the code.**

SOPs are the source of truth. Tools in `/tools/` are implementations of these SOPs.

## 📂 Structure

Each SOP should follow this template:

```markdown
# [Component Name]

**Version:** 1.0  
**Last Updated:** YYYY-MM-DD  
**Owner:** [Tool name in /tools/]

## Goal
What this accomplishes

## Input Schema
```json
{
  "field": "type"
}
```

## Process
1. Step one
2. Step two
3. Step three

## Output Schema
```json
{
  "result": "type"
}
```

## Edge Cases
- Case: Handling
- Case: Handling

## Dependencies
- API/Service name
- Environment variables needed
```

## 📝 Current SOPs

[SOPs will be added during Phase 3: Architect]
