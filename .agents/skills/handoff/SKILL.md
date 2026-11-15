---
name: handoff
description: Give the person a short note to paste into a new conversation. Use after the third change in one thread, when the person starts on something unrelated to what the thread began with, at the end of a wrap-up, and when the person says "hand off", "new thread" or "start fresh".
---

# Hand off

Each reply sends the whole thread to the model again. A long thread costs the person more of their plan, and the agent gets worse at keeping it all in mind. A new thread that starts from a short note is cheaper and works better. The person is new to this, so you give them the note and tell them what to do with it.

1. Finish what the person asked for first.
2. Bring the person's memory file up to date: the `.vibe-repo-101-config.json` you read at the start of the thread. In this project's entry under `projects`, set `what` to one sentence that is true now, and `updated` to today. Add to `notes` what this thread taught you about the person that a later thread needs. Keep the file under 60 lines: join notes that say the same thing.
3. End your reply with the note, in one code block, so the person can copy it in one tap. The first line and the last line of the block are six dashes. Keep it under 20 lines, in plain words:

   ```
   ------
   A note from my last conversation with my coding agent. The agent wrote it.
   Project: <the project's name, and what it is in one sentence>
   Version now: <the newest version, when the project has a site>
   I asked for: <in the person's own words where you have them>
   Done: <what is done, with the version it went live in>
   Not done: <what is not done, and why>
   I decided: <what the person decided, liked or did not like>
   Next step: <the one next step>
   ------
   ```

4. Above the block, tell the person in two plain sentences what to do: start a new conversation in this same folder, write what they want next in their own words, and paste the note before or after it. Say why in one sentence: a fresh conversation costs less and works better.

Give the note once per moment. If the person keeps going in this thread, go on with what they ask, and give a new note after three more changes.
