---
name: welcome
description: The person's first thread in a project made from vibe-repo-101. Use when no .vibe-repo-101-config.json exists in this folder or one folder above it. Do what they asked, greet them, give a short overview, and end by asking about them, so the next thread starts from what they said.
---

# Welcome

`.vibe-repo-101-config.json` is what coding agents remember about the person between threads and between projects. Git ignores it. Never commit it, and never put it in a reply as code.

## 1. Is the person new?

Look in the folders next to this one: `../*/.vibe-repo-101-config.json`.

- **One exists there.** The person has made a project from this template before. Take the newest one. Copy it to `../.vibe-repo-101-config.json`, one folder above this project, so all their projects share it. Add this project to `projects`. If you may not write there, tell the person in one sentence what to approve. If they say no, copy it into this folder. Then greet them by name, say in one sentence that you remember them from the other project, and go on with what they asked. Skip steps 3 and 4.
- **None exists.** The person is new. Go on with step 2.

## 2. Do what they asked

The first message is a real request. Do it first, by the rules in `AGENTS.md`. When the first message is only a hello, build the app and show it to them, as "Where the person sees the result" in `AGENTS.md` says.

If this is the person's own project and `README.md` still starts with `# vibe-repo-101`, make the project theirs before you publish anything:

1. Write a new `README.md`: the folder's name as the title, one sentence that says what the project is (or "A new project." when you do not know yet), and the line "Made with [vibe-repo-101](https://github.com/codeluggage/vibe-repo-101). To change it, read START-HERE.md."
2. Run `git rm LICENSE`. That file is the template's licence, and it allows this. Without it the project belongs to the person alone, until they choose a licence.
3. Commit with the message `start the project from the template`.

## 3. Greet them, at the top of your reply

Four or five plain sentences, warm, no list:

- Welcome them. Say what this folder is: a starting point for a website, an app or a browser game that they build by saying what they want.
- Say what you just did, and where they see it.
- Say how it stays safe: every change is checked before they see it, and "put it back" undoes any change.
- Say they can ask you anything, also "what do you think?" or "what can this do?".

No code, no file names, no list of commands.

## 4. Ask about them, at the end of your reply

End the reply with these three questions. Say that one line each is plenty.

1. What should I call you?
2. What do you want to make here: a website, an app, a game? A rough idea is enough.
3. Have you made something with code or with an AI agent before?

## 5. Write the file when they answer

When the person answers any of the questions, write `.vibe-repo-101-config.json` in this folder. Fill in what they said in their own words, and leave out what they did not say.

```json
{
  "about": "What coding agents remember about this person, for projects made from vibe-repo-101. Safe to read and edit by hand.",
  "person": {
    "name": "",
    "experience": "",
    "wants_to_make": "",
    "how_to_reply": "plain words, no code unless asked"
  },
  "projects": [
    { "folder": "", "what": "", "site": "", "updated": "" }
  ],
  "notes": []
}
```

- `experience`: what they said about code, agents and computers. "Never programmed" is a good answer.
- `projects`: this folder's full path, what the project is in one sentence, its site address when it has one, and today's date.
- `notes`: short dated sentences that a later thread needs. For example what they like, what they decided, what confused them.

Then go on with what they ask. Do not tell them about the file unless they ask what you remember.

If the person does not answer, ask once more at the end of your next reply, in one sentence. If they still do not answer, write the file from what this thread shows about them, and stop asking.

If the person says where they live and no version of this project is live yet, set `zone` in `dev/app/build.gleam` to their time zone, so the version shows their clock.
