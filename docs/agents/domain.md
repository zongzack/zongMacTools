# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- `CONTEXT.md` at the repo root.
- `CONTEXT-MAP.md` at the repo root if it exists; it points to relevant per-context `CONTEXT.md` files.
- `docs/adr/` for decisions that touch the area being changed.

If these files do not exist, proceed silently. The `/domain-modeling` skill creates them lazily when terminology or architectural decisions are actually resolved.

## File structure

This is a single-context repo:

```
/
|- CONTEXT.md
|- docs/adr/
`- src/
```

## Use the glossary's vocabulary

When naming a domain concept in an issue, proposal, hypothesis, or test, use the term defined in `CONTEXT.md`. If it is absent, reconsider whether it is new terminology or record the gap for `/domain-modeling`.

## Flag ADR conflicts

Surface any conflict with an existing ADR explicitly rather than silently overriding it.
