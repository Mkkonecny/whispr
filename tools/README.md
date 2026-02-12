# 🛠️ Tools Directory

This directory contains **deterministic Python scripts** that implement the SOPs defined in `/architecture/`.

## 🎯 Purpose

Each tool is:
- **Atomic:** Does one thing well
- **Testable:** Can be verified independently
- **Deterministic:** Same input = same output (no guessing)
- **Documented:** Maps to an SOP in `/architecture/`

## 📏 Rules

1. **No Business Logic Guessing:** If the logic is unclear, update the SOP first
2. **Environment Variables:** All tokens/keys go in `.env`
3. **Temporary Files:** Use `.tmp/` for all intermediate data
4. **Error Handling:** Implement self-annealing (log errors, suggest fixes)
5. **Imports:** Keep dependencies minimal and documented

## 🧪 Testing

Each tool should be testable via:
```bash
python tools/tool_name.py --test
```

## 📂 Current Tools

[Tools will be added during Phase 3: Architect]
