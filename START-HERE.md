# Start here

This folder is a starting point for a website, an app or a browser game. You build it by telling a coding agent what you want, in your own words. You do not need to know how to program. The agent writes the code, and the project checks every change before you see it.

You cannot break anything for good. Every change can be put back with one sentence.

## What you need

- A computer with Windows 11, macOS or Linux.
- A free [GitHub](https://github.com) account.
- A coding agent: Codex in the ChatGPT desktop app, or Claude Code.

## 1. Install the tools, once

**Windows.** Press the Windows key, type `PowerShell`, and press Enter. Paste these lines one at a time, and press Enter after each one:

```powershell
winget install --id Git.Git -e
winget install --id GitHub.cli -e
winget install --id Gleam.Gleam -e
winget install --id OpenJS.NodeJS.LTS -e
```

Close PowerShell and open it again, so it finds the new tools.

**macOS.** Install [Homebrew](https://brew.sh) if you do not have it. Then open Terminal and paste:

```sh
brew install git gh gleam node
```

**Then, on every system,** sign in to GitHub:

```sh
gh auth login
```

Choose `GitHub.com`, then `HTTPS`, then log in with a web browser.

Tell Git who you are. Paste these two lines one at a time, with your own GitHub name in both:

```sh
git config --global user.name "YOUR-GITHUB-NAME"
git config --global user.email "YOUR-GITHUB-NAME@users.noreply.github.com"
```

This address keeps your real email out of your projects.

## 2. Get the project

Pick one folder where all your projects live, and go there first.

On Windows use `C:\src`, because a folder that OneDrive syncs, such as Documents, can stop the agent from working:

```powershell
mkdir C:\src
cd C:\src
```

On macOS and Linux use a folder named `code` in your home folder:

```sh
mkdir -p ~/code
cd ~/code
```

Then choose one of two ways.

### Just try it

```sh
gh repo clone codeluggage/vibe-repo-101 vibe-repo-101-test
```

This copy runs on your own computer only. It is the fastest way to see what this is. You can make it your own later: tell your agent "make this my own project".

### Make it your own

```sh
gh repo create my-project --template codeluggage/vibe-repo-101 --public --clone
```

Write your own name for the project in place of `my-project`. You get your own project on GitHub, and a web address where it is live for any phone or computer.

- `--public` means anyone can read the project's code on GitHub. It is still yours.
- `--private` in place of `--public` keeps the code to yourself. GitHub puts a private project online only on a paid GitHub plan. On the free plan a private project runs on your own computer only.

You can also do this on the web: open [the template](https://github.com/codeluggage/vibe-repo-101), press "Use this template", then "Create a new repository". Then run `gh repo clone YOUR-GITHUB-NAME/my-project`.

Keep your projects next to each other in the same folder. Then your agent remembers you from one project to the next.

## 3. Open it in your agent

**Codex, in the ChatGPT desktop app**

1. Open the ChatGPT app and go to Codex.
2. Open the project's folder.
3. Choose "Ask for approval". Codex then asks you before it runs a command or uses the internet.
4. When Codex asks if you trust this project, say yes.
5. Open "Review hooks" and trust the two hooks. They run the checks after each change.
6. On Windows: open Settings, then "Computer use", and turn off the switch named "Any App". With it on, Codex can take over your mouse and your screen while it checks its work. If you do not see that setting, skip this step.

**Claude Code**

1. Open the project's folder in Claude Code.
2. When Claude asks if you trust this folder, say yes. The checks then run by themselves.

## 4. Say hello

Type this to your agent:

> Hi! Show me what this is.

The agent shows you the app and tells you where to look. At the end it asks you four short questions about you and what you want to make. Answer in your own words, one line each is plenty. It remembers your answers, so the next conversation starts from there.

## 5. Make your first change

> Change the app's name from "My app" to "Whatever You Like".

The agent makes the change, checks it, and shows it to you. In your own project this takes a few minutes, and the reply says which version is live, such as "Version 2026.11.13.1542 is live."

Open the app. If a bar says "New version", tap Reload. Check that the version at the top of the screen is the same.

## 6. Then undo it

> Put the name back the way it was.

A new version comes, with the old name. Now you know the way back from any change.

## What you can make with it

- **A website or a tool.** This is what the starter is. It works on phones and computers, installs like an app from the browser menu, and works offline.
- **An app for your own things.** Lists, trackers, notes, calculators. What you save stays in the browser on your device. There are no accounts.
- **A game.** Start it here, in the browser: you see every change in minutes, and you can play it on your phone. Card games, board games, puzzles and turn-based games fit as they are. A game with fast movement works too, and takes your agent a little more setup. When the game outgrows the browser, you move the idea to a game engine. By then you know the game is fun.
- **Something with accounts, or data that people share.** That needs a server, which this starter does not have. A server is an extra step that costs money to run. Ask your agent "does my idea need a server?" before you start. It will tell you plainly.

## Versions

The app shows its version at the top of every screen, such as 2026.11.13.1542. It is the date and time of the change. You can name a version by its last four digits: "I'm on 1542 and the button is still blue."

## Improvements from the starter

The starter your project came from gets better over time. When it has something new, your agent tells you once and puts it on its list. Say "upgrade" when you want it. Your own work stays as it is.

## How it stays safe

- The agent cannot finish a change that does not fit together. The project checks the code after every edit, and again before the agent may say it is done.
- In your own project, every change is checked once more before it goes live. A failed check publishes nothing, so the live app keeps working.
- "Put it back" undoes any change.
- What you save in the app survives updates.
- What you save lives in the browser on your device, and a browser can clear it. If your app holds things you would miss, ask your agent for a way to save a backup file.

## Good ways to ask

- Ask for one change at a time.
- Say what you see and what you want: "On the first screen the button is hard to tap on my phone. Make it bigger."
- Say which version you are on.
- "What do you think?" gets an answer and no change.
- "What can this do?" and "does my idea need a server?" are good questions.
- When you are done, say so: "that's all for now". The agent then tells you what it left unsaid: things it assumed, skipped or noticed, that you could not know to ask about.
- After a few changes the agent suggests a new conversation. A long conversation uses up your plan faster, and the agent gets worse at keeping it all in mind. Before it suggests that, the agent saves a numbered list of what is still open, such as #4 and #7, in the project folder. Start a new conversation in the same folder and say "continue" for the first point, name a number ("do 7"), or ask for something new. A point keeps its number until it is done. "Drop 4" removes a point.

## From your phone

Your agent's phone app may let you write to the agent on your computer while you are away from it. The computer must be on, awake and online, with the agent's desktop app running. Look for a remote control or connections setting in the desktop app.

## Optional: tell your agent how you like to work

If your agent has a place for personal instructions, paste this there once:

> When I ask you to change one of my apps or websites, I mean: make the change and show it to me at the usual address. Follow the project's own instructions for checks and publishing. Do any testing yourself, in the background: never take over my mouse, my keyboard or my own browser, because I use the computer while you work. When the change is ready, tell me in plain words what changed, the version I should see, and where to look. If you need me to approve something or decide something, tell me exactly what to do. If I say "what do you think?" or "show me an idea", only talk.

## If something goes wrong

- If the agent shows an error, ask it to fix the error.
- If the agent says to ask the person who helps with the project, send its last message to whoever showed you this. If nobody did, ask the agent to explain the message in plain words.
- If the agent says you reached a usage limit, wait and try again later.
- If the agent takes over your mouse or your browser while you do something else: in Codex, do step 6 of "Open it in your agent" above. Then tell the agent once "your checks get in my way, stop using the browser". It remembers that for every later conversation.
