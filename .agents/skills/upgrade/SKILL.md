---
name: upgrade
description: Bring the newest improvements from the starter (vibe-repo-101) into this project, and keep everything the person made. Use when the person says "upgrade", "update the starter" or "get the improvements", or names the open point in handoff.md about the starter.
---

# Upgrade from the starter

This project was made from the starter at https://github.com/codeluggage/vibe-repo-101. The starter gets better over time: your rules, the skills, the checks, the publish command. An upgrade brings those changes in and keeps everything the person made. Every command here works the same on Windows, macOS and Linux.

## 1. Start clean

Run `git status --porcelain`. When it lists anything, commit it first with a short lowercase message.

## 2. Connect to the starter

1. Run `git remote get-url upstream`. When it fails, run `git remote add --no-tags upstream https://github.com/codeluggage/vibe-repo-101`. `--no-tags` keeps the starter's own versions out of this project's list of versions.
2. Run `git fetch --no-tags upstream`.
3. Run `git merge-base HEAD upstream/main`. When it prints a commit, the project is connected: go to part 3.
4. When it prints nothing, connect once. This tells git which version of the starter the project began from, so it can tell the person's changes from the starter's.
   - `git rev-list --max-parents=0 HEAD` prints the project's first commit. Call it FIRST.
   - `git log -1 --format=%T FIRST` prints the tree of FIRST.
   - `git log upstream/main --format="%T %H %ci %s"` lists the starter's commits. START is the commit on the line whose first word is the tree of FIRST.
   - When no line has it, run `git log -1 --format=%ci FIRST`. START is the newest commit in the list with an earlier date.
   - Run `git merge -s ours --allow-unrelated-histories -m "connect to the starter" START`. It changes no file.

## 3. Tell the person what is new

`git log --format=%s HEAD..upstream/main` lists the starter's changes that this project does not have yet. When it lists nothing, say that the project has the newest starter, and stop.

Otherwise say in two to five plain sentences what the person will notice, and what changes in how you work. Then go on.

## 4. Merge

Run `git merge --no-edit upstream/main`. When it ends with no conflict, go to part 6.

## 5. Settle each conflict

`git diff --name-only --diff-filter=U` lists the files in conflict. For each file:

- **The starter's version wins** in files that decide how checks, hooks, build and publish work: everything in `.agents/`, `.codex/`, `.claude/`, `.github/` and `dev/app/`, and `CLAUDE.md`, `START-HERE.md`, `.gitignore`, `.gitattributes`. Run `git checkout --theirs -- <file>`. When the person had changed the file, write what they wanted as one line under "Your rules" at the end of `AGENTS.md`.
- **`AGENTS.md`:** take the starter's version with `git checkout --theirs -- AGENTS.md`. Then put back the person's own rules under "Your rules" at its end. Read them in the old file with `git show HEAD:AGENTS.md`: its "Your rules" part, and any rule there that the person asked for and the starter's text does not have.
- **`README.md` and `LICENSE`** are the person's. Run `git checkout --ours -- <file>`. When the person had removed the file, run `git rm <file>`.
- **`gleam.toml`:** keep every dependency from both sides. **`manifest.toml`:** take the person's version, `gleam check` brings it up to date.
- **Everything else** (`src/`, `test/`, `web/`) is the person's app. Keep what the app does for the person, and add the starter's change where it fits. When you cannot tell, keep the person's version.

Run `git add <file>` after each file. When a conflict is too unclear to settle, run `git merge --abort`. Then nothing has changed: tell the person in one sentence, and ask them to ask the person who helps with the project.

## 6. Check, finish and publish

1. Run `gleam check`, `gleam test` and `gleam run -m app/build`. Fix what fails.
2. When the merge is still open, finish it with `git commit --no-edit`.
3. Publish as "Make a change" in `AGENTS.md` says, from step 6.
4. Move the starter point in `handoff.md` to "Done", with the version.
5. Reply with what changed, in plain words, and where in the app the person sees it.

## Undo

The "Undo" steps in `AGENTS.md` do not undo an upgrade. When the person wants an upgrade out again, tell them to ask the person who helps with the project.
