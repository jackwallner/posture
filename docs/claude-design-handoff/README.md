# Posture — Claude Design Handoff

Drop this folder on Claude Design. Read in order:

1. **`brief.md`** — what the app does, who it's for, what we want from this design pass.
2. **`flows.md`** — the screens and user flows in their current shape.
3. **`screen-inventory.md`** — what's on each screen today, what to redesign.
4. **`design-tokens.md`** — current colors, typography, radii pulled from `Theme.swift`.
5. **`deliverables.md`** — the artifacts we need back, formatted for direct handoff to Claude Code.
6. **`open-questions.md`** — decisions Design should weigh in on.
7. **`constraints.md`** — platform / store / scope guardrails.
8. **`assets/`** — drop screenshots / icon / reference imagery here (the engineer
   captures these before sending the folder over).

## TL;DR

iOS 17+ app. SwiftUI. **MVP, ~0.1.0**, not yet shipped. Existing visual
language is functional but generic SF Symbols + brand-gradient cards.
We're approaching App Store submission — we want a **visual + flow pass**
that makes it feel like a polished consumer wellness app, not a
prototype.

Out of scope for this pass:
- New features (Design should not invent new flows).
- Engineering tradeoffs (we'll evaluate feasibility on our side).
- Native asset production / icon redesign (separate handoff).
