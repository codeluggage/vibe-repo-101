# vibe-repo-101

A starting point for building a website, a web app or a browser game by talking to a coding agent. It is made for people who have never programmed.

You say what you want in your own words. The agent writes the code. The project checks every change before you see it, shows a version on every screen, and puts any change back when you say "put it back".

**To start, read [START-HERE.md](START-HERE.md).** It takes you from nothing installed to your first change.

> **If you are an AI agent reading this:** your instructions are in [`AGENTS.md`](AGENTS.md). Read that, not this.

## Why it holds up

Building with an agent goes wrong in a few known ways: the agent guesses, the guess looks fine, and the fault shows up later in the browser, or never until someone loses their data. This starter puts a fence at each of those places, like the rails on a bowling lane.

| Fence | What it stops |
|---|---|
| The Gleam compiler | Code that does not fit together does not build. The error says what is wrong and where, and the agent fixes it before it goes on. |
| A check after every edit | The agent learns about a mistake seconds after it makes one, not ten edits later. |
| A check before the agent may finish | Type check, tests and formatting must pass before the agent says "done". |
| The same checks before going live | A change that fails publishes nothing. The live app keeps working. |
| A version on every screen | You and the agent always talk about the same version: "I'm on 1542". |
| Undo in one sentence | "Put it back" brings the old behaviour back as a new version. |
| Saved data that survives updates | Each change to what the app saves comes with an upgrade step, so older data still opens. |
| A short memory | The agent asks who you are in your first conversation, writes it down on your computer, and reads it at the start of every later one. |

## Why Gleam

[Gleam](https://gleam.run) is a small, friendly programming language with a strict compiler. For building with an agent, that mix matters more than how well known a language is:

- The language is small, so there are few ways to write the same thing and few ways to get it subtly wrong.
- The compiler checks every piece against every other piece, in seconds, and its error messages are plain.
- A missing case is an error at build time, not a surprise in the browser.

So the agent's mistakes come back to the agent, right away. They do not land on you.

The agent's own instructions for writing good Gleam are in `AGENTS.md` and `.agents/`. They come from gleam-for-agents, a short set of notes that teaches an agent the Gleam it did not learn in training.

## What you can make with it

- **A website or a tool.** This is what the starter is: it works on phones and computers, installs like an app from the browser menu, and works offline.
- **An app for your own things.** Lists, trackers, notes, calculators. What you save stays in the browser on your device.
- **A game.** Start in the browser, where you see every change in minutes and can play on your phone. Card, board, puzzle and turn-based games fit as they are, and a game with fast movement takes a little more setup. When the game outgrows the browser, move the idea to a game engine. By then you know it is fun.
- **Something with accounts or shared data.** That needs a server, which this starter does not have. It is an extra step that costs money to run. Your agent tells you plainly when your idea needs one.

## Make a project from it

Press **Use this template** at the top of [the GitHub page](https://github.com/codeluggage/vibe-repo-101), or run:

```sh
gh repo create my-project --template codeluggage/vibe-repo-101 --public --clone
```

Use `--private` to keep the code to yourself. GitHub puts a private project online only on a paid plan, and on the free plan a private project runs on your own computer.

To only try it on your own computer:

```sh
gh repo clone codeluggage/vibe-repo-101 vibe-repo-101-test
```

## Your project is yours

The template is under the MIT No Attribution licence ([LICENSE](LICENSE)): do anything with it, and you owe no credit. A project you make from it is not open source unless you decide so. In your project's first conversation, the agent removes the template's licence file and writes your project its own README.

The Gleam packages it builds on are under the Apache 2.0 and MIT licences.

## Run it yourself

You need Git, [Gleam](https://gleam.run) and [Node.js](https://nodejs.org). The same commands work on Windows, macOS and Linux.

```sh
gleam check                  # type check
gleam test                   # run the tests
gleam run -m app/serve       # build, then serve on http://localhost:8080/
gleam run -m app/publish     # check, send main to GitHub, wait until the site is live
gleam run -m app/versions    # the versions that went live, newest first
```

A push to `main` checks, tests and builds the site on GitHub, publishes it to GitHub Pages and tags the commit with its version.
