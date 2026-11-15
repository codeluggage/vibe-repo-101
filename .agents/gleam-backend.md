# gleam-backend.md - backend web framework (Wisp v2.x), domain patterns, full-stack shape

> Companion to [AGENTS.md](../AGENTS.md). Read when building HTTP handlers, routing, wiring the server, or modeling domain types. DB access -> [gleam-data.md](gleam-data.md); JSON decode -> [gleam-stdlib.md](gleam-stdlib.md).

Handler: `fn(Request, Context) -> Response` (Context holds DB conn, secrets). Middleware: a fn taking a response-returning callback as its last arg - compose with `use <-`. Validate every piece of user input with `Result`/`case`; bad input is a response (`bad_request`/`not_found`/`internal_server_error`), never a crash.

```gleam
import wisp.{type Request, type Response}
import gleam/http
pub type Context { Context(db: pog.Connection, static_dir: String) }

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes               // panic -> 500, not a dead socket
  use req <- wisp.handle_head(req)
  use <- wisp.serve_static(req, under: "/static", from: ctx.static_dir)
  case wisp.path_segments(req) {
    [] -> home(req, ctx)
    ["api", "users"] -> users(req, ctx)
    _ -> wisp.not_found()
  }
}
fn users(req, ctx) -> Response {
  use <- wisp.require_method(req, http.Post)     // else 405
  use json <- wisp.require_json(req)             // else 415; yields Dynamic
  case decode.run(json, create_user_decoder()) {
    Ok(input) -> wisp.json_response(json.to_string(payload), 201)
    Error(_) -> wisp.bad_request("invalid body")
  }
}
```

Middleware (callback last -> `use <-`): `log_request(req, handler)` / `rescue_crashes(handler)` / `serve_static(req, under, from, next)` / `handle_head(req, next)` / `require_method(req, method, next)` / `require_json(req, fn(Dynamic)->_)` / `require_string_body` / `require_form(fn(FormData)->_)` / `require_content_type`. Decode `require_form` bodies with `formal` (type-safe HTML form decode + validation) instead of pulling fields out of `FormData` by hand.

Responses: `ok() created() no_content() not_found() bad_request(String) internal_server_error() method_not_allowed(List(Method)) response(Int)` / setters `set_body json_response(json, status) html_response json_body html_body string_body`. Types: `Request = request.Request(Connection)`, `Response = response.Response(Body)`. `wisp.Connection` = HTTP body conn, unrelated to `pog.Connection`. Also `path_segments(req)`, `random_string(n)`.

Logging (Erlang logger, each `fn(String) -> Nil`, one per syslog level): `log_emergency log_alert log_critical log_error log_warning log_notice log_info log_debug` / `configure_logger()` (min=info, call once in main) / `set_logger_level(LogLevel)`. Log before a 500, render cause with inspect: `wisp.log_error("DB insert failed: " <> string.inspect(e))`. `log_request`/`rescue_crashes` are the middleware forms; `log_*` are direct calls in handlers.

Startup - serve over `mist` via the `wisp/wisp_mist` module:

```gleam
import mist
import wisp/wisp_mist
pub fn main() {
  wisp.configure_logger()
  let ctx = Context(db: start_pool(), static_dir: "priv/static")
  let assert Ok(_) =
    wisp_mist.handler(fn(req) { handle_request(req, ctx) }, wisp.random_string(64))  // secret_key_base
    |> mist.new |> mist.port(8000) |> mist.start                    // mist.start, NOT mist.start_http
  process.sleep_forever()
}
```

Read env vars (`DATABASE_URL`, secrets, port) with `envoy` - `envoy.get(name) -> Result(String, Nil)` (zero-dep, all targets). Bind config from there; don't hardcode.

Deploy: add `mist.bind("0.0.0.0")` before `mist.port` so it listens outside localhost - in a container the default binds localhost and looks dead from outside. The production build is `gleam export erlang-shipment` -> a self-contained release in `build/erlang-shipment/` with an `entrypoint.sh` (`./entrypoint.sh run`); ship that directory in a container, not the source tree.

## Domain patterns

AGENTS.md section 1 covers the mechanics (`use` guard chains, opaque types). The patterns that emerge:

**Value Object** - opaque + smart constructor returning `Result`. Validate once; type carries proof everywhere:

```gleam
pub opaque type Email { Email(value: String) }
pub type EmailError { Empty MissingAt TooManyAt MissingTextBeforeAt MissingTextAfterAt }
pub fn new(raw: String) -> Result(Email, EmailError) {
  case string.split(string.trim(raw), "@") {
    [""] -> Error(Empty)            [_] -> Error(MissingAt)
    ["", _] -> Error(MissingTextBeforeAt)   [_, ""] -> Error(MissingTextAfterAt)
    [_, _] -> Ok(Email(string.trim(raw)))   _ -> Error(TooManyAt)
  }
}
pub fn to_string(e: Email) -> String { e.value }
```

**Aggregate** - module = consistency boundary. `OrderLine` unexported -> invisible outside. Each `use <-` = one named domain rule:

```gleam
pub fn add_line(order, sku, qty, price) -> Result(Order, OrderError) {
  use <- no_modify_placed(order)
  use <- positive_qty(qty)
  Ok(Order(..order, lines: [OrderLine(sku, qty, price), ..order.lines]))
}
```

**Domain Events** - past-tense names; failures emit NO events. Transition returns `#(new_state, List(Event))`. Drive sequences with `list.try_fold`:

```gleam
pub fn place(order) -> Result(#(Order, List(OrderEvent)), OrderError) {
  use <- no_modify_placed(order)
  case order.lines {
    [] -> Error(CannotPlaceEmptyOrder)
    _ -> { use t <- result.try(total(order))
           Ok(#(Order(..order, status: Placed), [OrderPlaced(order.id, t)])) }
  }
}
```

**Entity identity** - `same_customer(a, b) = a.id == b.id`. `==` on opaque value objects IS safe (same invariants); `==` on entities is wrong (snapshots differ).

## Full-stack shape

Postgres (`.sql`) <- pog supervised pool / Squirrel generates typed query fns -> `pog.execute(query, ctx.db)` / Wisp middleware->route->query->`gleam/json`->`json_response` / Lustre (JS) calls the JSON API with `rsvp`, decodes with `dynamic/decode`. Domain modules (opaque types + `use <-` guard chains, see AGENTS.md section 1) sit between handler and DB: validate raw input -> build value objects/aggregates -> persist. If the client is served from a different origin than the API, add CORS with `cors_builder` (works with wisp/mist) - browsers block the cross-origin calls otherwise.

Backend and frontend are SEPARATE Gleam projects (different targets/deps - one `gleam.toml` can't be both BEAM and JS):

```
myapp/
  server/   gleam.toml (target = "erlang")      wisp, mist, pog, gleam_otp, ...
  client/   gleam.toml (target = "javascript")  lustre, rsvp, ...
  shared/   gleam.toml (optional)               pure types + decoders imported by both (no pog/wisp/mist - BEAM-only)
```

Each subdir is its own project (`gleam new <name>`). Minimal client `gleam.toml`: `name`, `version`, `gleam = ">= 1.15.0"`, `target = "javascript"`, empty `[dependencies]`/`[dev-dependencies]`. Serve compiled client from Wisp: `gleam build` (client) emits ESM to `build/dev/javascript/<pkg>/<pkg>.mjs` + deps; point `serve_static` at that dir (or copy `.mjs` into server `priv/static`), load with `<script type="module" src="/static/<pkg>.mjs">`. Its `main()` mounts the Lustre app on `#app`.

Module namespacing inside a project: nest modules under `src/<package_name>/` - `src/myapp/user.gleam` is module `myapp/user` (same shape as `wisp/wisp_mist`). This keeps your modules in their own namespace so they never collide with a dependency's top-level names. `test/` = tests; optional `dev/` = dev-only entry points (Squirrel runner, seed scripts) kept out of the release build. Group those files by domain (`user.gleam`, `order.gleam`), never by pattern (`helpers/`, `factories/`) - see AGENTS.md section 2.
