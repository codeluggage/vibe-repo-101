//// The notes feature: the notes saved on this device, adding and removing
//// one, and the screen of one note. It is the example of a feature: a new
//// feature is a module shaped like this one. The shell in `app.gleam` holds
//// its `State`, wraps its `Msg`, and sends it the note routes.

import app/browser
import app/effects
import app/route
import app/storage.{type Database, type StorageError}
import gleam/dynamic/decode
import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type State {
  State(
    /// `None` until the saved notes are read.
    notes: Option(Result(List(Note), StorageError)),
    /// What is typed in the text field and not added yet.
    draft: String,
    problem: Option(Problem),
  )
}

/// A saved note. `added` is when, in milliseconds since 1970 UTC.
pub type Note {
  Note(id: String, text: String, added: Int)
}

/// What went wrong with the last add or remove.
pub type Problem {
  NotSaved(StorageError)
  NotRemoved(StorageError)
  NoStorage
}

pub type Msg {
  NotesLoaded(Result(List(Note), StorageError))
  DraftChanged(String)
  AddSubmitted
  NoteSaved(Result(Note, StorageError))
  RemoveClicked(id: String)
  NoteRemoved(id: String, result: Result(Nil, StorageError))
}

pub fn init() -> State {
  State(notes: None, draft: "", problem: None)
}

/// Read the saved notes once storage has answered. When storage did not open,
/// the notes show why.
pub fn load(db: Result(Database, StorageError)) -> Effect(Msg) {
  case db {
    Ok(db) -> effects.from_promise(fn() { load_notes(db) }, NotesLoaded)
    Error(error) -> {
      use dispatch <- effect.from
      dispatch(NotesLoaded(Error(error)))
    }
  }
}

/// `db` is the open database or the reason it is not open, and `None` while
/// it opens.
pub fn update(
  state: State,
  msg: Msg,
  db: Option(Result(Database, StorageError)),
) -> #(State, Effect(Msg)) {
  case msg {
    NotesLoaded(notes) -> #(State(..state, notes: Some(notes)), effect.none())
    DraftChanged(draft) -> #(State(..state, draft:), effect.none())
    AddSubmitted ->
      case string.trim(state.draft), db {
        "", _ -> #(state, effect.none())
        text, Some(Ok(db)) -> #(
          State(..state, problem: None),
          effects.from_promise(fn() { save_note(db, text) }, NoteSaved),
        )
        _, _ -> #(State(..state, problem: Some(NoStorage)), effect.none())
      }
    // The draft goes only once the note is saved, so a failed save keeps it.
    NoteSaved(Ok(note)) -> #(
      State(..state, notes: Some(Ok([note, ..saved(state)])), draft: ""),
      effect.none(),
    )
    NoteSaved(Error(error)) -> #(
      State(..state, problem: Some(NotSaved(error))),
      effect.none(),
    )
    RemoveClicked(id:) ->
      case db {
        Some(Ok(db)) -> #(
          State(..state, problem: None),
          effects.from_promise(
            fn() { storage.delete(db, storage.Notes, id) },
            fn(done) { NoteRemoved(id:, result: done) },
          ),
        )
        _ -> #(State(..state, problem: Some(NoStorage)), effect.none())
      }
    NoteRemoved(id:, result: Ok(Nil)) -> {
      let notes = list.filter(saved(state), fn(note) { note.id != id })
      #(State(..state, notes: Some(Ok(notes))), effect.none())
    }
    NoteRemoved(result: Error(error), ..) -> #(
      State(..state, problem: Some(NotRemoved(error))),
      effect.none(),
    )
  }
}

/// The screen changed: the last problem goes.
pub fn screen_changed(state: State) -> State {
  State(..state, problem: None)
}

fn saved(state: State) -> List(Note) {
  case state.notes {
    Some(Ok(notes)) -> notes
    Some(Error(_)) | None -> []
  }
}

/// The newest note first.
pub fn newest_first(notes: List(Note)) -> List(Note) {
  list.sort(notes, fn(a, b) { int.compare(b.added, a.added) })
}

/// A note as it is saved, under its id as the key.
pub fn to_json(note: Note) -> json.Json {
  json.object([
    #("text", json.string(note.text)),
    #("added", json.int(note.added)),
  ])
}

/// A saved note's record: its text and when it was added. Its id is the key.
pub fn record_decoder() -> decode.Decoder(#(String, Int)) {
  use text <- decode.field("text", decode.string)
  use added <- decode.field("added", decode.int)
  decode.success(#(text, added))
}

/// Every saved note. One that cannot be read makes the whole read fail with
/// its key, so a broken note is seen, never quietly left out.
fn load_notes(db: Database) -> Promise(Result(List(Note), StorageError)) {
  use records <- promise.map(storage.get_all(
    db,
    storage.Notes,
    record_decoder(),
  ))
  use records <- result.try(records)
  use #(id, record) <- list.try_map(records)
  use #(text, added) <- result.map(record)
  Note(id:, text:, added:)
}

fn save_note(
  db: Database,
  text: String,
) -> Promise(Result(Note, StorageError)) {
  let note = Note(id: browser.random_id(), text:, added: browser.now_ms())
  storage.put(db, storage.Notes, note.id, to_json(note))
  |> promise.map(result.replace(_, note))
}

// --- Views ------------------------------------------------------------------

/// The notes' part of the home screen: the field to add one, the last
/// problem, then the saved notes, newest first.
pub fn home(state: State) -> List(Element(Msg)) {
  [
    html.h2([], [html.text("Notes")]),
    html.form(
      [attribute.class("add"), event.on_submit(fn(_) { AddSubmitted })],
      [
        html.label([attribute.for("note-text")], [html.text("New note")]),
        html.input([
          attribute.id("note-text"),
          attribute.type_("text"),
          attribute.value(state.draft),
          event.on_input(DraftChanged),
        ]),
        html.button(
          [attribute.type_("submit"), attribute.class("button primary")],
          [
            html.text("Add"),
          ],
        ),
      ],
    ),
    case state.problem {
      None -> element.none()
      Some(problem) ->
        html.p([attribute.class("problem"), attribute.role("alert")], [
          html.text(describe_problem(problem)),
        ])
    },
    notes_view(state),
  ]
}

fn notes_view(state: State) -> Element(Msg) {
  case state.notes {
    None ->
      html.p([attribute.class("muted")], [html.text("Opening the notes…")])
    Some(Error(error)) ->
      html.p([attribute.class("muted")], [
        html.text(
          "The saved notes could not be read. " <> storage.describe_error(error),
        ),
      ])
    Some(Ok([])) ->
      html.p([attribute.class("muted")], [
        html.text("No notes yet. Write one above and tap Add."),
      ])
    Some(Ok(notes)) ->
      html.ul(
        [attribute.class("rows")],
        list.map(newest_first(notes), fn(note) {
          html.li([], [
            html.a(
              [
                attribute.class("row-link"),
                attribute.href(route.to_hash(route.NotePage(note.id))),
              ],
              [html.text(note.text)],
            ),
            html.button(
              [
                attribute.type_("button"),
                attribute.class("button"),
                event.on_click(RemoveClicked(note.id)),
              ],
              [html.text("Remove")],
            ),
          ])
        }),
      )
  }
}

/// The screen of one note, or a plain message when it is not there.
pub fn note_page(state: State, note_id: String) -> List(Element(Msg)) {
  let back =
    html.a(
      [attribute.class("back"), attribute.href(route.to_hash(route.Home))],
      [
        html.span([attribute.aria_hidden(True)], [html.text("← ")]),
        html.text("All notes"),
      ],
    )
  let message = fn(text) {
    [back, html.p([attribute.class("muted")], [html.text(text)])]
  }
  case state.notes {
    None -> message("Opening…")
    Some(Error(error)) ->
      message(
        "The saved notes could not be read. " <> storage.describe_error(error),
      )
    Some(Ok(notes)) ->
      case list.find(notes, fn(note) { note.id == note_id }) {
        Error(Nil) -> message("This note is not on this device.")
        Ok(note) -> [
          back,
          html.h1([], [html.text("Note")]),
          html.p([attribute.class("prose")], [html.text(note.text)]),
          html.p([attribute.class("muted")], [
            html.text("Added " <> browser.local_time(note.added)),
          ]),
        ]
      }
  }
}

fn describe_problem(problem: Problem) -> String {
  case problem {
    NotSaved(error) ->
      "The note could not be saved. " <> storage.describe_error(error)
    NotRemoved(error) ->
      "The note could not be removed. " <> storage.describe_error(error)
    NoStorage -> "Storage is not open on this device, so notes cannot change."
  }
}
