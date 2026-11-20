---
name: handoff
description: Bring handoff.md up to date and tell the person to start a new conversation. handoff.md is the numbered list of open points that every new thread reads first. Use after the third change in one thread, when the person starts on something unrelated to what the thread began with, at the end of a wrap-up, and when the person says "hand off", "new thread" or "start fresh".
---

# Hand off

Each reply sends the whole thread to the model again. A long thread costs the person more of their plan, and the agent gets worse at keeping it all in mind. A new thread that starts from a short list is cheaper and works better. The person is new to this, so you keep the list for them and tell them what to do.

`handoff.md` is the list this project keeps between threads. It stays on disk in the project folder, and every new thread reads it first. Each point in it has a number, so the person can say "do 4" or "drop 6" in any thread. Git ignores the file, so do not commit it.

## The numbers

- A point keeps its number for as long as it exists. Never change a number.
- A new point gets the number after `Last number used`. Then raise `Last number used`. A number is never used twice, also after its point is gone.
- Write a point as `- #4 text`, in the file and in every reply. Never write the points as a numbered list (`4.`): the app that shows your reply would count them again from the first one.

## Steps

1. Finish what the person asked for first.
2. Bring the person's memory file up to date: the `.vibe-repo-101-config.json` you read at the start of the thread. In this project's entry under `projects`, set `what` to one sentence that is true now, and `updated` to today. Add to `notes` what this thread taught you about the person that a later thread needs. Keep the file under 60 lines: join notes that say the same thing.
3. Read `handoff.md` if it exists. Keep its points and their numbers.
4. Write the file again in this shape. Keep it under 40 lines.

   ```markdown
   # Between threads

   Updated: 2026-11-20. Version now: 2026.11.20.1542. Last number used: 7.

   ## Open, in the order to do them

   - #5 The button on the first screen is still hard to tap on a phone. Asked for, not started.
   - #3 Nobody looked at the dark colours after the colour change.
   - #7 The person's idea: sort the notes by date.

   ## Done, newest first

   - #6 Bigger text on the note screen. In version 2026.11.20.1542.
   - #4 The newest note comes first. In version 2026.11.19.2031.

   ## What the person decided

   - Keep the green colours.
   ```

   - The version comes from publish or build in this thread.
   - **Open** holds every point that still needs something done, checked or decided. The first one is the next step. Write each point in one or two plain sentences that a thread which knows nothing else can act on: what, where in the app, and why it is open. Use the person's own words where you have them.
   - **Done** holds the five newest points that are done, each with its version. Remove older ones.
   - **What the person decided** holds what they chose, liked or did not like, when a later thread needs it. Keep it under 8 lines.
   - When the person says "drop 6", remove that point.
   - When the file does not fit in 40 lines, ask the person which open points to drop.
5. End your reply with the points under "Open", copied from the file: the same order, the same numbers, the same words. Then tell the person in two plain sentences what to do: start a new conversation in this same folder, and say "continue" for the first point, name a number, or ask for something new. Say why in one sentence: a fresh conversation costs less and works better, and the list is saved, so nothing is lost.

Do this once per moment. If the person keeps going in this thread, go on with what they ask, and hand off again after three more changes.
