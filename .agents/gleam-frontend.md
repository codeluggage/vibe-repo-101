# gleam-frontend.md - Elm-style MVU frontend (Lustre, rsvp, JS FFI)

> Companion to [AGENTS.md](../AGENTS.md). Read when building the frontend. Client is a SEPARATE `target = "javascript"` project (see project layout in [gleam-backend.md](gleam-backend.md)). HTTP decoding reuses `dynamic/decode` ([gleam-stdlib.md](gleam-stdlib.md)).

Model (state) / view (Model->Element) / update (Model,Msg->Model). `lustre.simple` for pure; `lustre.application` when you need `Effect` (side effects).

```gleam
import lustre
import lustre/element/html.{div, button, p}
import lustre/element.{text}
import lustre/event.{on_click}

pub fn main() { let assert Ok(_) = lustre.start(lustre.simple(init, update, view), "#app", Nil) }
fn init(_flags) { 0 }                          // Model = Int
type Message { Incr Decr }
fn update(model, msg) { case msg { Incr -> model + 1  Decr -> model - 1 } }
fn view(model) {
  div([], [
    button([on_click(Incr)], [text(" + ")]),
    p([], [text(int.to_string(model))]),
    button([on_click(Decr)], [text(" - ")]),
  ])
}
```

```gleam
simple(init: fn(args)->model, update: fn(model,msg)->model, view: fn(model)->Element(msg)) -> App
application(init: fn(args)->#(model, Effect(msg)), update: fn(model,msg)->#(model, Effect(msg)), view) -> App
start(app, onto: String, with: args) -> Result(Runtime(msg), Error)
component(init, update, view, options) -> App
```

Elements: `html.div/button/p/ul/li/...` each `(List(Attribute(msg)), List(Element(msg)))`; `element.text(String)`. Snapshot a view with `element.to_string(view(model)) |> birdie.snap(...)` - see [gleam-testing.md](gleam-testing.md).

**Events** (`lustre/event`): `on_click(msg)` / `on_input(fn(String)->msg)` / `on_change(fn(String)->msg)` / `on(name, decode.Decoder(msg))` (ANY DOM event) / `prevent_default` / `stop_propagation`. No built-in drag/drop - use `event.on("drop"|"dragover"|"dragleave", decoder)` + `prevent_default` (else browser opens the file). Forward whole event to FFI by decoding as `Dynamic`:

```gleam
html.div([
  event.on("drop", decode.map(decode.dynamic, Dropped)) |> event.prevent_default,
  event.on("dragover", decode.success(DragOver)) |> event.prevent_default,
], [html.text("drop files here")])
```

```javascript
// ffi.mjs - pull files off the raw event; dispatch is a Gleam fn(String, String)
export function read_dropped_files(event, dispatch) {
  const files = event.dataTransfer?.files ?? [];
  for (const file of files) {
    const reader = new FileReader();
    reader.onload = () => dispatch(file.name, reader.result);   // a plain JS call
    reader.readAsText(file);
  }
}
```

JS-target FFI: a Gleam callback `fn(String, String)` passed into `.mjs` is a plain two-argument JS function, so call it `cb(a, b)`. Gleam functions are not curried in JS. `@external` declaration syntax is in AGENTS.md section 1.

**Attributes** (`lustre/attribute`): `attribute(name, value)` (escape hatch) / `class id value placeholder href src name type_` / `style(prop, value)` SINGLE / `styles(List(#(String,String)))` MANY / `disabled(Bool) checked(Bool)`.

**Effects** (`lustre/effect`) - async into MVU: `none()` / `batch(List(Effect))` / `from(fn(dispatch)->Nil)` (the callback arg IS dispatch). Bridge any async/side-effecting browser API here; dispatch a msg from its completion callback (mind currying):

```gleam
fn read_file_effect(file) { effect.from(fn(dispatch) { read_file(file, fn(c) { dispatch(FileRead(c)) }) }) }
//  FilesDropped(files) -> #(model, effect.batch(list.map(files, read_file_effect)))
```

**Backend HTTP - `rsvp`** (stdlib has no JS HTTP client; NOT `lustre_http`). Returns `Effect(msg)`:

```gleam
import rsvp
// get(url, Handler) -> Effect  /  post(url, body: json.Json, Handler) -> Effect
// expect_json(decoder, fn(Result(a, Error))->msg) -> Handler  /  expect_text(...)
// Error: BadBody | BadUrl | HttpError(Response) | JsonError(json.DecodeError) | NetworkError | UnhandledResponse(Response)
LoadUsers -> #(model, rsvp.get("/api/users", rsvp.expect_json(users_decoder(), GotUsers)))
GotUsers(Ok(users)) -> #(Model(..model, users:), effect.none())
```
