# CLAUDE.md - Claude Code configuration

<!-- gleam-for-agents:v1 -->

`AGENTS.md` is the primary reference. Claude Code loads it by itself. It holds the Gleam check loop, the idiom rules, and this project's rules for working with the person. Read it before you act.

The hooks are already on, in `.claude/settings.json`: `gleam check` after each edit, and check, test and format before you finish. Both call the scripts in `.agents/hooks/`.

The skills are in `.agents/skills/` (`welcome`, `wrap-up`, `handoff`, `upgrade`). `AGENTS.md` says when each one applies. Read the skill's `SKILL.md` at that moment.
