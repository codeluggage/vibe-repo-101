---
name: welcome
description: The person's first thread in a project made from vibe-repo-101. Use when no .vibe-repo-101-config.json exists in this folder or one folder above it. Do what they asked, greet them, give a short overview, and end by asking about them, so the next thread starts from what they said.
---

# Welcome

`.vibe-repo-101-config.json` is what coding agents remember about the person between threads and between projects. Git ignores it. Never commit it, and never put it in a reply as code.

It is in one of two places: this folder, or one folder above it. Look there and nowhere else. Do not search the person's other folders for it.

## 1. Do what they asked

The first message is a real request. Do it first, by the rules in `AGENTS.md`. When the first message is a hello, or asks what this is, start the app and show it to them, as "Where the person sees the result" in `AGENTS.md` says. Do not describe the files.

If this is the person's own project and `README.md` still starts with `# vibe-repo-101`, make the project theirs before you publish anything:

1. Write a new `README.md`: the folder's name as the title, one sentence that says what the project is (or "A new project." when you do not know yet), and the line "Made with [vibe-repo-101](https://github.com/codeluggage/vibe-repo-101). To change it, read START-HERE.md."
2. Run `git rm LICENSE`. That file is the template's licence, and it allows this. Without it the project belongs to the person alone, until they choose a licence.
3. Commit with the message `start the project from the template`.

## 2. Greet them, at the top of your reply

Four or five plain sentences, warm, no list:

- Welcome them. Say what this folder is: a starting point for a website, an app or a browser game that they build by saying what they want.
- Say what you just did, and where they see it.
- Say how it stays safe: every change is checked before they see it, and "put it back" undoes any change.
- Say they can ask you anything, also "what do you think?" or "what can this do?".

No code, no file names, no list of commands.

## 3. Ask about them, at the end of your reply

End the reply with these four questions. Say that one line each is plenty.

1. What should I call you?
2. What do you want to make here: a website, an app, a game? A rough idea is enough.
3. Have you made something with code or with an AI agent before?
4. Have you used this starter before, in another project?

## 4. Write the file when they answer

**They have not used the starter before.** Write `.vibe-repo-101-config.json` in this folder. Fill in what they said in their own words, and leave out what they did not say.

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

**They have used the starter before.** Their other project has the file already. Ask for the name of that project's folder. Read only that one file, `.vibe-repo-101-config.json` in the folder they name. When both projects are in the same folder, write the file one folder above this one, so every project there shares it, and add this project to `projects`. Otherwise write it in this folder. If you may not read or write there, tell the person in one sentence what to approve. If they say no, ask them to copy the file into this folder themselves.

Then go on with what they ask. Do not tell them about the file unless they ask what you remember.

If the person does not answer, ask once more at the end of your next reply, in one sentence. If they still do not answer, write the file in this folder from what this thread shows about them, and stop asking.

If the person says where they live and no version of this project is live yet, set `zone` in `dev/app/build.gleam` to their time zone, so the version shows their clock.
