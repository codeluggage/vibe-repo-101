# gleam-testing.md - verification loop, tests, snapshots, terminal docs

> Companion to [AGENTS.md](../AGENTS.md). AGENTS.md section 0 names the verification ladder; this file is the how-to. Same rule: run it, don't reason about it. Checked against `gleam 1.16`, `gleeunit 1.10`, `birdie` (latest) on this machine.

## The verification ladder - pick the cheapest rung that proves the thing

The compiler is rung 0 and catches most mistakes for free. Climb only as far as the *kind* of mistake demands:

| Rung | Catches | Cost | Tool |
|---|---|---|---|
| 0. `gleam check` (or `build`) | type/variant/arity/exhaustiveness - most bugs | ~2s, run after edits (save hook can automate) | compiler |
| 1. `gleam test` (gleeunit) | logic that compiles but is wrong - wrong branch, off-by-one, bad decode | seconds | gleeunit |
| 2. `gleam run -m birdie` after `gleam test` | structure/visual regressions - rendered HTML changed unexpectedly | seconds | birdie |
| 3. drive the running app | **it actually works end-to-end** - boots, routes, DB, real pixels | manual / browser | `gleam run` + curl/browser |

The point of rungs 1-2: a tight local feedback loop where compiler + tests + snapshots give enough certainty that you rarely need to stop and read external docs. Don't reach for rung 3 to catch a rung-1 bug, and don't trust rung 0 to catch a logic error - a type-correct wrong answer compiles fine.

What each rung does not prove:
- Compiler says nothing about whether the logic is right, only that it's typed.
- gleeunit says nothing about how it looks.
- Birdie snaps text/HTML strings, not pixels - it proves the rendered markup didn't change, not that it renders attractively. Real visual confirmation is still rung 3.

---

## Rung 1 - gleeunit (unit tests)

Already the default test dep (`gleam add --dev gleeunit` if missing). Test files live in `test/`, run with `gleam test` (runs every `pub fn *_test`). One `main` that calls `gleeunit.main()` discovers them.

```gleam
// test/myapp_test.gleam
import gleeunit
import myapp/email

pub fn main() { gleeunit.main() }   // discovers all *_test fns under test/

// modern idiom: the `assert` keyword (compiles to a crash w/ a good message on failure)
pub fn email_rejects_blank_test() {
  assert email.new("") == Error(email.Empty)
}
pub fn email_accepts_valid_test() {
  let assert Ok(e) = email.new("a@b.com")
  assert email.to_string(e) == "a@b.com"
}
```

`assert <expr>` is the lean modern form. The `gleeunit/should` helpers still exist and are fine if you prefer named assertions: `should.equal`, `should.not_equal`, `should.be_ok`, `should.be_error`, `should.be_true`, `should.be_false` - e.g. `email.new("") |> should.be_error`.

What to actually test (don't test the compiler's job): domain logic with branches - smart-constructor validation (gleam-backend.md value objects), `case` that picks a path, decoders, money/order rules, anything where a typed answer can still be the wrong answer. Skip trivial getters.

---

## Rung 2 - Birdie (snapshot tests, incl. Lustre views)

`gleam add --dev birdie`. Birdie snapshots a String: first run records it; later runs diff against the recorded one and fail (panic) until you review. Use it to lock down anything whose exact output matters and is tedious to assert by hand - rendered Lustre HTML, JSON encoder output, formatted text.

```gleam
import birdie
import gleeunit

pub fn main() { gleeunit.main() }

pub fn greeting_snapshot_test() {
  "<div><h1>Hello</h1></div>"
  |> birdie.snap(title: "greeting renders heading")   // title MUST be unique across the project
}
```

`birdie.snap(content content: String, title title: String) -> Nil`. The `title` is the snapshot's identity - must be unique repo-wide or Birdie errors.

### Snapshotting a Lustre view

Render the view to an HTML string with `element.to_string`, then snap it. This pins the markup a given `Model` produces - catches accidental structure changes in `view`:

```gleam
import birdie
import lustre/element
import myapp/ui          // your Lustre module exposing view(model) -> Element(msg)

pub fn empty_state_snapshot_test() {
  ui.view(ui.init(Nil))
  |> element.to_string
  |> birdie.snap(title: "ui: empty state")
}
```

(Reminder: this proves the HTML string is stable, not that it looks good - that's rung 3.)

### Review workflow - a new/changed snapshot FAILS the test on purpose

```
gleam test            # new or changed snapshot -> test panics: "run `gleam run -m birdie` to review"
gleam run -m birdie   # interactive review: [a]ccept  [r]eject  [s]kip  [d] toggle diff
```

Accepted snapshots are written to `test/birdie_snapshots/<title-slug>.accepted`. Commit those files - they ARE the test baseline; a teammate/CI without them can't verify. Reject (`r`) discards a wrong change so the test keeps failing until the code is fixed.

Non-interactive accept (scripting/agent loop, no TTY): pipe the key in  - 
```
echo a | gleam run -m birdie    # accept the pending snapshot(s)
```
Only do this once you've *seen* the diff is correct; blind-accepting defeats the test.

CI / staleness check: no separate "birdie check" - a `.new` (unreviewed) or mismatched snapshot makes `gleam test` itself fail, so plain `gleam test` in CI is the gate. Don't commit `.new` files.

---

## Rung 3 - drive the running app

Unchanged from AGENTS.md section 0: `gleam run` the server, `curl localhost:8000/...` or open it, confirm boot + real behavior. Only rung that proves pixels and the full Postgres->Wisp->Lustre path. A demo never started is unverified.

---

## Terminal doc lookup - tighten the loop, skip the website

Let the tool answer, don't guess - same move for API signatures. You rarely need hexdocs in a browser: the real source of every dependency is on disk after `gleam add`/build:

```
build/packages/<pkg>/src/*.gleam      # exact, version-correct source of every dep
```

So the fastest "what's the signature of X" is grep, not WebFetch:

```bash
grep -rn "pub fn snap"  build/packages/birdie/src/
grep -rn "pub fn "      build/packages/wisp/src/wisp.gleam     # list wisp's whole API
grep -rn "pub type "    build/packages/pog/src/pog.gleam       # see a sum type's real variants
```

This beats memory and beats hexdocs: it's the code that will actually compile against your locked versions.

Other built-in lookups:
- `gleam export package-interface --out=iface.json` - JSON of **your own project's** modules/types/fns (not deps). Good for a machine-readable map of what you've built.
- `gleam shell` - Erlang REPL with your code loaded, to poke a fn interactively.
- `gleam docs build` - render a package's HTML docs locally (heavier; grep is usually enough).

There is no `gleam` subcommand that fetches a remote hex package's docs - the on-disk dep source above is the substitute, and it's better (exact versions).

---

## The edit->check loop (hook) and extending it

The primary loop is agent-driven: run `gleam check` yourself after each edit. A save hook just automates it - `scripts/gleam-check.sh` is harness-agnostic (wire it to an editor save hook, git pre-commit, or a harness post-edit hook). Under Claude Code it runs on every `Edit`/`Write` (`PostToolUse`, `BLOCK_ON_FAIL=1`): it walks up to the nearest `gleam.toml` and runs `gleam check`, feeding failures back. That keeps rung 0 automatic so you never drift far from a green compile. Other harnesses (Codex, GLM, etc.) won't have the hook - there, just run `gleam check` after edits.

It's a check gate, not a test gate - keep it fast. Run rungs 1-2 yourself at natural checkpoints (after a logic change: `gleam test`; after a `view` change: `gleam test` then review snapshots), not on every keystroke. If you later want tests in the hook, gate them behind an env flag so the common edit stays a sub-second check, e.g. `RUN_TESTS=1 gleam test` only on demand. Always `gleam format` before declaring done.
