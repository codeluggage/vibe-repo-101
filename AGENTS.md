# AGENTS.md - Gleam full-stack reference

> Verified against: Gleam 1.16, June 2026. Thinned 2026-09-06 against Claude Fable 5.1, Claude Opus 4.7 and GPT-6 (the `eval/` directory in the shim repo holds the runs). Package names, API shapes and version traps were checked at that vintage. Re-verify before trusting them much later.

Gleam (+ Lustre for web frontend). Not Next.js/TS. A dense, verified head-start, not a substitute for the compiler. Lowercase identifiers in a signature (`name`, `acc`, `t`, `e`) are type variables, not concrete types.

## 0. Workflow - the compiler is your oracle

Use the type-checker as a loop, not a final exam. The failure mode is guessing an API and writing a whole file blind.

**The tell: you are narrating confidence about an API in prose.** "From my knowledge of Wisp...", "I'm confident `||` works", "`require_form` returns a `FormData` with...". That sentence is the bug. Your memory of a fast-moving ecosystem is not evidence. One `grep -rn "pub fn " build/packages/<pkg>/src/` or one `gleam check` is, and both are free. Catch yourself writing such a sentence, stop, grep or compile, then write.

- `gleam check` after every change: fast type/variant/arity/exhaustiveness feedback, no codegen. The error names the exact type, variant or arity. Compile to learn a signature, never guess. `scripts/gleam-check.sh` wraps it for a save or post-edit hook.
- Never invent a constructor, variant or function to fill a gap. Unsure of a sum type's variants? Write `case x { _ -> ... }`, compile, and read the "unmatched variants" warning. It lists the real names.
- Add deps with `gleam add <pkg>`. Do not hand-edit `[dependencies]`, do not resolve hex versions in your head, do not pin to dodge a conflict you have not seen.
- `let assert`/`panic`/`todo` are not escape hatches for API uncertainty. They are for impossible states.
- Validate by running, not reading. `gleam run` the server, hit an endpoint, confirm it responds. A demo never started is unverified.
- Loop: write small, `gleam check`, fix, repeat, `gleam run`, exercise it, `gleam format` before done.

Verification ladder. Climb only as far as the mistake demands. A type-correct wrong answer compiles fine: logic needs tests, visuals need a browser.

1. `gleam check` - types, variants, arity, exhaustiveness.
2. `gleam test` (gleeunit) - logic that compiles but is wrong.
3. `gleam run -m birdie` after `gleam test` - structure regressions via snapshot (HTML and text, not pixels).
4. Drive the running app (curl or browser) - end to end, real pixels.

How-to (gleeunit, Birdie, terminal doc-grep): [.agents/gleam-testing.md](.agents/gleam-testing.md).

Doc lookup without the website: after `gleam add`, every dep's source is on disk. `grep -rn "pub fn " build/packages/<pkg>/src/<mod>.gleam` beats hexdocs (exact locked version). No `gleam` command fetches remote docs.

Tooling: `gleam check|build|test|run|format`, `gleam fix` (rewrites deprecated code the compiler flags), `gleam add <pkg>` (`--dev` for `gleeunit`, `birdie`). One file = one module, filename = module name, `pub` exports. Needs Gleam >= 1.15. Pin the floor in `gleam.toml`: `gleam = ">= 1.15.0"`.

Hex package names (modules != packages, do not guess):

| `import` | `gleam add` |
|---|---|
| `gleam/io`, `gleam/list`, `gleam/dict`, `gleam/dynamic/decode`, ... | `gleam_stdlib` (default) |
| `gleam/http`, `gleam/http/request` | `gleam_http` (a direct dep you must add, Wisp uses it) |
| `gleam/erlang/process` | `gleam_erlang` |
| `gleam/otp/...`, `gleam/otp/actor` | `gleam_otp` |
| `gleam/json` | `gleam_json` |
| `wisp`, `wisp/wisp_mist` | `wisp` (`wisp_mist` is a module inside wisp, NOT a package) |
| `mist` | `mist` |
| `pog` | `pog` |
| `lustre`, `lustre/element`, `lustre/event` | `lustre` |
| `rsvp` | `rsvp` (the Lustre HTTP client, NOT `lustre_http`, which no longer compiles) |
| `gleam/time/calendar`, `gleam/time/timestamp` | `gleam_time` |
| `youid/uuid` | `youid` |

Typical backend: `gleam add wisp mist pog gleam_http gleam_erlang gleam_otp gleam_json`. Need a package not in this table? Search [packages.gleam.run](https://packages.gleam.run) or [gloogle.run](https://gloogle.run) (searches fn names and type signatures across the ecosystem). Find it, `gleam add` it, then grep its source.

---

## 1. Language semantics - the parts models still get wrong

You know the syntax. These are the places where the shape of the language differs from what training data suggests.

`use` is the one control-flow primitive. Mechanical rule, whole feature:

```gleam
use a, b <- f(arg1, arg2)
rest
// desugars EXACTLY to:
f(arg1, arg2, fn(a, b) { rest })
```

It lifts the rest of the block into an anonymous fn passed as `f`'s last argument. Binding count = callback arity. The body's last expression is what `f` returns. Result chaining is `use x <- result.try(...)` with the last line an `Ok(...)`, error types lifted with `result.map_error`. A zero-arg callback (`use <- guard(...)`) short-circuits, and a chain of named guards reads as policy (examples in [.agents/gleam-backend.md](.agents/gleam-backend.md)). Do not reach for `use` when the body is one statement.

Opaque types are the make-illegal-states-unrepresentable lever. Outside the module the type exists but the constructor and field access do not. Validate once in a smart constructor returning `Result`, then pass the type around as proof. Forgetting `opaque` leaks the constructor and makes the invariant bypassable.

```gleam
pub opaque type Email { Email(value: String) }
```

Crash-only constructs (`let assert`, `assert`, `panic`, `todo`, `echo`) are for debug, tests and impossible states. Bad input or a failed external call is a `Result`, never a crash. Strip `echo` before shipping.

Decoding `Dynamic` is `gleam/dynamic/decode`: `use x <- decode.field(name, decode.string)` then `decode.success`, run with `decode.run`. The old `dynamic.decode2` / `dynamic.field` decoders are gone. Catalog in [.agents/gleam-stdlib.md](.agents/gleam-stdlib.md).

JS-target FFI: `@external(javascript, "./ffi.mjs", "name")` above a bodiless `fn` with a full signature. A Gleam `fn(a, b)` compiles to a plain two-argument JS function, lambdas and constructors included, so JS calls a Gleam callback as `cb(a, b)` (run on Gleam 1.19.2, October 2026). Detail in [.agents/gleam-frontend.md](.agents/gleam-frontend.md).

---

## 2. Naming & idiom - write Gleam that looks like Gleam

This stops you writing TS/Python-in-Gleam that compiles but reads foreign. Condensed from gleam.run's *Conventions, patterns, and anti-patterns*, the "idiomatic Gleam" source most models lack in training.

Naming:

| Thing | Rule | Yes | No |
|---|---|---|---|
| Module / file | singular, `snake_case` | `user`, `order_line` | `users`, `orderLine` |
| Type / constructor | `UpperCamel`; acronym = ONE word | `Json`, `HttpClient`, `UserId` | `JSON`, `HTTPClient`, `UserID` |
| Fn / var / arg | `snake_case`, spelled out | `parse_request`, `count` | `parseRequest`, `cnt`, `usr` |
| Type to type conversion | `x_to_y` | `to_string`, `int.to_float` | `stringify`, `as_string` |
| Fallible, no domain noun | `try_` prefix | `try_parse` | `parse_safe` |

Idiom, the common cross-language mistakes:
- Annotate every top-level `fn` (arg + return types), let `let`-locals infer. The signature is the contract the compiler enforces and the doc the next reader trusts.
- Custom type, not `Bool`/`String`, for a closed set: `type Visibility { Public Private }` over `is_public: Bool`. `f(True, False)` at a call site is unreadable, named variants + exhaustive `case` are not. Opaque value objects (section 1) are the strong form.
- Descriptive error variants, never a bare string: `Error(MissingAt)`, not `Error("bad email")`, so callers `case` on it. This is the rule every model still breaks most.
- Builder, not a mega-constructor, for optional fields: start from a `default`, pipe setters. Do not hand a record 9 positional args.
- `Dynamic` lives only at the edge: JSON/FFI/DB hand you `Dynamic`, `decode.run` it into a real type immediately and keep that type from there on. Never thread `Dynamic` through your domain.
- Qualify by default (`string.trim`, not unqualified `trim`). Unqualify only types + their constructors (`option.{type Option, Some, None}`).
- Group by domain, not by layer or pattern: `user.gleam`, `order.gleam`, not `models/`, `utils/`, `helpers/`. Do not fragment a module for size alone.
- Exhaustive `case` on your own sum types lists every variant. Drop the trailing `_ ->` so adding a variant later is a compile error. Reach for `_ ->` only for an external error enum you do not own, or a true all-others-identical default.

---

## 3. Topic files - read the ONE for the layer you are about to touch

| Working on... | Read |
|---|---|
| stdlib fn names / signatures / `dynamic/decode` engine | [.agents/gleam-stdlib.md](.agents/gleam-stdlib.md) |
| JSON encode/parse, Postgres (`pog`), Squirrel SQL codegen | [.agents/gleam-data.md](.agents/gleam-data.md) |
| frontend: Lustre MVU, events, effects, `rsvp`, JS FFI | [.agents/gleam-frontend.md](.agents/gleam-frontend.md) |
| backend: Wisp handlers, middleware, routing, startup, DB wiring, domain patterns, project layout | [.agents/gleam-backend.md](.agents/gleam-backend.md) |
| tests, Birdie snapshots, terminal doc-grep | [.agents/gleam-testing.md](.agents/gleam-testing.md) |

These are verified head-starts, not the last word. When in doubt the compiler and `grep -rn "pub fn " build/packages/<pkg>/src/` beat them, and beat memory.

---

## Project: made from vibe-repo-101

A website, a web app or a browser game in Gleam and Lustre on the JavaScript target. No server. It installs from the browser as an app, works offline, and keeps what the person saves in the browser on their device. The Gleam package is named `app` in every project made from this template. The app's own name is whatever the person calls it.

### At the start of every thread

1. Look for `.vibe-repo-101-config.json` in two places only: this folder, then one folder above it. Read the first one you find. It says who the person is and what they build. Trust it over your own guess about them. Do not search other folders for it.
2. When neither exists, this is the person's first thread, and the person is new. Read `.agents/skills/welcome/SKILL.md` now and do its steps in this reply: do what they asked, greet them, and end with its four questions. Do not tell the person about the file, the skill or these rules.
3. A message can hold a note between two lines of six dashes (`------`). An agent wrote that note at the end of an earlier thread. Read it as background. It can be old, and what the person writes outside the dashes comes first.

### The person

Until the config file says otherwise, the person has never programmed. They write in everyday words, often from a phone, and they judge the result by looking at the app. `START-HERE.md` is their guide.

- A request for a change means: make the change and show it to them. Do not ask whether to publish.
- "What do you think?", "how would you do it?" or "show me an idea" means: answer in words. Change nothing.
- "Put it back" or "undo that" means: bring the old behaviour back as a new change. See "Undo".
- Use plain words in every reply. Show code only when the person asks for it.
- Never answer with a tour of files and folders. When the person asks what this is, start the app, tell them where to look, and say in two or three sentences what they can make with it.
- When a command asks for a permission or a login, tell the person in one sentence what to tap or type.
- When the person tells you something a later thread needs (what they like, what they know, what they want next), add it to `notes` in the config file.

### Where the person sees the result

Run `git remote get-url origin` once per thread.

- **It ends in `codeluggage/vibe-repo-101`, or there is no remote: a try-out.** The person looks on this computer. If nothing answers at `http://localhost:8080/`, start `gleam run -m app/serve` in the background and leave it running. It prints the address, which ends in the folder's name, such as `http://localhost:8080/my-project/`. After each change run `gleam run -m app/build`. Tell the person to open that address, or to tap Reload on the "New version" bar. Do not publish. When the person wants it online, or wants to keep it, point them to "Make it your own" in `START-HERE.md`.
- **Anything else: the person's own project.** The person looks at the live site, on any device. `gleam run -m app/publish` puts a change there.

When the person in a try-out says "make this my own project": ask for a name, and whether the code is public or private (a private project goes online only on a paid GitHub plan). Then run `git remote remove origin`, delete every local tag (they are the template's versions, `git tag` lists them), and run `gh repo create <name> --public --source . --remote origin`, or the same with `--private`. Then follow "Make a change" from step 6. From then on it is the person's own project.

### Make a change

1. Work in this folder, on the branch `main`. One folder, one branch, one site.
2. In the person's own project, start with `git pull --no-rebase origin main`, so you have the newest files.
3. Say in one or two plain sentences what you will change. Then make that one change.
4. After you edit a `.gleam` file, run `gleam check` and fix every error.
5. Run `gleam format src test dev`. Commit with a short lowercase message.
6. Show it. In a try-out: `gleam run -m app/build`. In the person's own project: `gleam run -m app/publish`. It checks the code, publishes it, and waits until the site is live.
7. If publish stops, read its last lines. Fix what they name, commit, and run publish again. If the lines say to ask the person who helps with the project, tell the person exactly that and stop.
8. If publish was cut off before it printed its last two lines, run it again. With nothing new to send, it picks up the wait where it was.
9. Reply with what changed and where in the app to look. After a publish, include the last two lines that publish printed.

`gleam run -m app/publish` is the only way you publish. Do not run `git push` yourself.

### Versions

- The app shows its version at the top of every screen, like `2026.11.13.1542`. It is the date and the time of the build, on the clock named by `zone` in `dev/app/build.gleam`.
- The person names a version by its last four digits. "I'm on 1542" means the version that ends in `1542`.
- To find a version that went live, run `gleam run -m app/versions 1542`. It prints the versions that match and what changed in each.
- When the person names a time in words, such as "an hour ago", run `gleam run -m app/versions`, show the newest five with what changed, and ask which one they mean.
- The build makes each version. You read it from the output of publish or build. You do not write one.

### Undo

1. Find the change the person means: with the versions command in their own project, with `git log` in a try-out.
2. Run `git revert --no-edit <commit>` on the commits that made it, newest first. Skip a commit whose message starts with "Merge", and skip a commit named `publish again`: it is empty, and `git revert` stops on it.
3. Then follow "Make a change" from step 4.
4. Leave `upgrades` in `src/app/storage.gleam` as it is, even when the change you undo added a store. Remove the screens and keep the store. A browser that already has the store cannot open an app that has fewer.

### What the person saved

The browser is the only store, and what the person saved there is theirs. A change to what is saved raises the storage schema version and adds an upgrade step, so data saved by an older version still opens. "Adding a store" below is the way. Never edit or reorder a step that has shipped.

### Wrap up and hand off

The person is new to working with an agent. They do not know to ask what you left unsaid, and they do not know that a long thread costs more and works worse. So you do both without being asked.

- **When the person says they are done, or that the thing is finished:** use the `wrap-up` skill in `.agents/skills/wrap-up/`. It says what was left unsaid in this thread.
- **After the third change in one thread, or when the person starts on something unrelated to what the thread began with:** finish what they asked, then use the `handoff` skill in `.agents/skills/handoff/`. It gives the person a short note between two lines of six dashes, to paste into a new thread.
- "Wrap up" and "hand off" from the person mean the same two skills.

### What fits, and what needs more

Say this to the person in plain words before you build, when their idea needs more than the starter gives.

- **Fits as it is:** a website, a tool, an app for one person's own data, and a game drawn with HTML and CSS (cards, boards, puzzles, turns, text, idle games).
- **A game with fast movement:** draw on a `<canvas>` through a small FFI file. The game's state and its rules stay in Gleam as plain functions with tests, one step per frame. When the game needs what a browser cannot give, it can move to a game engine later, and the rules written here are the design to port.
- **Needs a server:** accounts, data that several people share, payments, and any secret such as an API key. This template has no server. Say so, and say that a server costs money and upkeep. Gleam runs servers too ([.agents/gleam-backend.md](.agents/gleam-backend.md)), as a second project beside this one.

### Always

- No password, token or API key in this code. Everything here is sent to the browser of anyone who opens the site.
- All logic is Gleam. A `.mjs` FFI file exists only to call a browser API, and each FFI function is a few lines with no decisions in it.
- Write the small thing in Gleam before you add a package. When a package is needed, add it with `gleam add` and tell the person in one sentence what it is for. No npm packages and no bundler.
- Paths in the static shell are relative, because the site is served from a sub-path.
- The compiler cannot see the FFI files or `web/`. After a change there, run the app and look at it.
- Leave `.codex/`, `.claude/` and `.agents/hooks/` alone. A change there turns the checks off until the person trusts the hooks again.
- Never commit `.vibe-repo-101-config.json`.

### Commands

The same commands on Windows, macOS and Linux, with only Git, the GitHub CLI, Gleam and Node installed:

| Command | Does |
|---|---|
| `gleam check` | type check |
| `gleam test` | the tests |
| `gleam format src test dev` | format |
| `gleam run -m app/build` | compile, then write the site to `dist/` |
| `gleam run -m app/serve [port]` | build, then serve `dist/` at `http://localhost:8080/<folder name>/`, port 8080 unless given |
| `gleam run -m app/publish` | take the saved work on `main` to the live site, wait until it is live, and print which version is live |
| `gleam run -m app/versions [digits]` | the ten newest versions that went live, each with what changed; with digits, only the ones that match |
| `gleam run -m app/live_check` | after a build: may `dist/` replace the live site? Exits 1 with the reason when it may not |

### Layout

- `src/app.gleam` - the shell: the app's name (`const name`), the version line at the top of every screen and the "New version" bar with Reload, the service worker, opening storage, the route and scroll, the home screen's frame and "About this device", and the wiring of each feature.
- `src/app/notes.gleam` - the example feature: notes saved on this device, adding and removing one, and the screen of one note. A new feature is a module shaped like this one.
- `src/app/storage.gleam` + `storage_ffi.mjs` - IndexedDB behind promises of `Result`: the schema (`upgrades`), the database named after the folder of the page so each site keeps its own, `get`, `put`, `get_all`, `delete`, many writes in one transaction, and the persistent storage request.
- `src/app/browser.gleam` + `browser_ffi.mjs` - page-level browser calls: the stamped version and commit, the page's path, `version.json`, the service worker, tab visibility, the clock, the URL hash, scroll and random ids.
- `src/app/effects.gleam` - effects the shell and the features share: a promise's value as a message.
- `src/app/route.gleam` - the screen in the URL hash: `parse`, `to_hash` and the `hashchange` listener.
- `src/app/version.gleam` - the version a person can say: parse, compare, and `version.json` written and read.
- `web/` - the static shell: `index.html`, `manifest.webmanifest`, `sw.js`, `style.css`, `icons/`. `__VERSION__`, `__COMMIT__` and `__FILES__` are placeholders the build replaces.
- `dev/app/build.gleam`, `serve.gleam` + `node_ffi.mjs` - the build and serve commands, run on Node. `zone` in `build.gleam` is the clock of the version.
- `dev/app/publish.gleam` - the publish command: take in GitHub's `main`, run the checks and the build, ask the live site whether the storage schema number is lower, turn the website on at GitHub when it is off, push, wait for the deploy run and the live site. Every sentence it ends with is in `say`.
- `dev/app/versions.gleam`, `live_check.gleam`, `site.gleam` - the versions command, the live check, and the GitHub repository and site address read from the `origin` remote.
- `.github/workflows/deploy.yml` - on a push to `main`: check, test, build, live check, deploy to GitHub Pages, then tag the commit with its version.
- `test/` - gleeunit tests, one file per module.
- `dist/` - build output, ignored by git.
- `.agents/gleam-*.md` - the Gleam topic files of section 3. `.agents/skills/` - `welcome`, `wrap-up`, `handoff`. `.agents/hooks/` - the two checks.
- `.codex/hooks.json`, `.claude/settings.json` - run the two checks in Codex and in Claude Code: `gleam check` after each edit, and check, test and format before the agent finishes.
- `START-HERE.md` - the person's guide.

The app's name is in three places: `const name` in `src/app.gleam`, `<title>` in `web/index.html`, and `name` and `short_name` in `web/manifest.webmanifest`. Two tests in `test/app_test.gleam` hold the name too. Change all of them together.

### Adding a store

The schema lives in `src/app/storage.gleam`. Each step in `upgrades` moves a database up one schema version, and the schema version is the number of steps. A browser that holds an older database runs every step it has not run yet, so data saved by an older version still opens.

1. Add a variant to `Store` and give it a name in `store_name`.
2. Append one step to `upgrades` that lists the new store: `[[Meta, Notes], [Scores]]`.
3. Run `gleam test`, then update the schema tests in `test/app/storage_test.gleam` to the new version.

Never edit or reorder a step that has shipped. A browser that already ran it will not run it again.

### Adding a feature

A feature is one module under `src/app/`, shaped like `notes.gleam`. It imports no other feature.

1. In the module, define `State`, `Msg`, `init() -> State` and `update(state, msg, db) -> #(State, Effect(Msg))`. `db` is the shell's `model.storage`.
2. Keep its effects in the module. What it reads from storage starts in `load`.
3. Make each screen a `pub fn` that returns `List(Element(Msg))`, and add its routes to `route.gleam`.
4. Wire it into `src/app.gleam` in three places, each next to the line that does the same for notes:
   - `Model` gets one field for the feature's `State`, set from its `init()` in `init`.
   - `Msg` gets one variant that wraps the feature's `Msg`, as `NotesMsg` does. `update` hands it to the feature's `update` and maps the effect back, and `StorageOpened` maps the feature's `load`.
   - `view` sends each of the feature's routes to its screen and maps the elements, as `notes_view` does.
5. State that should go when the screen changes goes through a function like `notes.screen_changed`, called from `HashChanged`.
6. Put its tests in `test/app/<feature>_test.gleam`.

When the person's app has no use for notes, remove the notes screens and keep the `Notes` store in `upgrades`.
