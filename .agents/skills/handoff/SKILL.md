---
name: handoff
description: Write handoff.md, a short note that the next thread reads first, and bring the person's config file up to date. Use when the person says "hand off", "new thread" or "start fresh", and as the last step of a wrap-up.
---

# Hand off

`handoff.md` is a note from this thread to the next one. It is for the agent, not the person. Git ignores it, so do not commit it.

1. Write `handoff.md` in the project folder, over the old one. Keep it under 30 lines:
   - the date, and the newest live version when the project has a site: from publish in this thread, or from `gleam run -m app/versions`,
   - what the person asked for, in their own words where you have them,
   - what is done, with the version it went live in,
   - what is not done, and why,
   - what the person decided, liked or did not like,
   - the one next step.
2. Open the `.vibe-repo-101-config.json` you read at the start of the thread. In this project's entry under `projects`, set `what` to one sentence that is true now, and `updated` to today. Add to `notes` what this thread taught you about the person that the next project also needs. Keep the file under 60 lines: join old notes that say the same thing.
3. End your reply with one sentence: the person can start a new thread now, and the new thread reads the note by itself.
