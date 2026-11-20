---
name: wrap-up
description: Say what was left unsaid, as numbered points, when the work is done. Use when the person says they are done, that the thing is finished, "that's all", "thanks, perfect" or "wrap up". A person new to agents does not know to ask for this, so do it without being asked.
---

# Wrap up

While the work was going on, you kept things to yourself that did not fit the moment. The person does not know to ask for them. Now is the time to say them, and to save them with a number, so a later thread can go on from them.

1. Write from what this thread already holds. Read `handoff.md` for its points and its `Last number used`. Read no other file and run no command to build the list.
2. Find what was left unsaid in this thread. Put first anything you told the person earlier in this thread that is wrong now. Then look for:
   - something you assumed and did not check,
   - a step you skipped, or a check that did not run,
   - something that may look wrong in the app,
   - a request you did only in part,
   - something you noticed and did not mention,
   - what you would do differently now.

   Skip what is empty.
3. Give each point the next free number, by the rules in `.agents/skills/handoff/SKILL.md`. Start your reply with the line "What I left unsaid:" and the points, each as `- #8 text` in one or two plain sentences. When there is nothing, say "Nothing left unsaid."
4. Then follow the handoff skill in `.agents/skills/handoff/SKILL.md`. The points from step 3 go into `handoff.md` under "Open" with the same numbers, in the order to do them, together with the points that were already there.
