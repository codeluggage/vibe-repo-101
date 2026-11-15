//// The shell around the features. Opens storage, asks the browser to keep it,
//// records the first visit, follows the screen in the URL hash, and offers a
//// reload when a newer build is out. Each feature keeps its own state,
//// messages and screens in its own module, and the shell sends it the routes
//// it owns. The notes feature is `app/notes`.

import app/browser
import app/effects
import app/notes
import app/route.{type Route}
import app/storage.{type Database, type Persistence, type StorageError}
import app/version
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

/// The app's name at the top of the home screen. The `<title>` in
/// `web/index.html` and the names in `web/manifest.webmanifest` hold it too.
const name = "My app"

pub fn main() -> Nil {
  let flags =
    Flags(
      running: browser.running_version(),
      commit: browser.running_commit(),
      hash: route.current_hash(),
    )
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", flags)
  Nil
}

/// What the page knows at start: the stamped version and commit, and
/// `location.hash`.
pub type Flags {
  Flags(running: String, commit: String, hash: String)
}

/// Each `Option` is `None` until the browser answers.
pub type Model {
  Model(
    running: String,
    commit: String,
    route: Route,
    storage: Option(Result(Database, StorageError)),
    persistence: Option(Persistence),
    first_opened: Option(Result(Int, StorageError)),
    notes: notes.State,
    /// How far down each screen was when it was left, keyed by its hash.
    scroll: Dict(String, Float),
    update: Update,
  )
}

pub type Update {
  UpToDate
  Available
  Applying
}

pub type Msg {
  StorageOpened(Result(Database, StorageError))
  FirstOpenedLoaded(Result(Int, StorageError))
  PersistAnswered(Persistence)
  VersionFetched(Result(String, String))
  VisibilityChanged(String)
  ReloadClicked
  WorkerActivated(Bool)
  ControllerChanged
  HashChanged(hash: String, left_at: Float)
  NotesMsg(notes.Msg)
}

const first_opened_key = "first_opened"

pub fn init(flags: Flags) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      running: flags.running,
      commit: flags.commit,
      route: route.parse(flags.hash),
      storage: None,
      persistence: None,
      first_opened: None,
      notes: notes.init(),
      scroll: dict.new(),
      update: UpToDate,
    )
  #(
    model,
    effect.batch([
      effects.from_promise(storage.open, StorageOpened),
      effects.from_promise(storage.persist, PersistAnswered),
      check_version(),
      listen(),
    ]),
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    StorageOpened(Ok(db)) -> #(
      Model(..model, storage: Some(Ok(db))),
      effect.batch([
        effects.from_promise(fn() { load_first_opened(db) }, FirstOpenedLoaded),
        notes.load(Ok(db)) |> effect.map(NotesMsg),
      ]),
    )
    StorageOpened(Error(error)) -> #(
      Model(
        ..model,
        storage: Some(Error(error)),
        first_opened: Some(Error(error)),
      ),
      notes.load(Error(error)) |> effect.map(NotesMsg),
    )
    FirstOpenedLoaded(result) -> #(
      Model(..model, first_opened: Some(result)),
      effect.none(),
    )
    PersistAnswered(answer) -> #(
      Model(..model, persistence: Some(answer)),
      effect.none(),
    )
    VersionFetched(fetched) -> #(
      Model(..model, update: update_after_fetch(model, fetched)),
      effect.none(),
    )
    VisibilityChanged("visible") -> #(model, check_version())
    VisibilityChanged(_) -> #(model, effect.none())
    ReloadClicked -> #(
      Model(..model, update: Applying),
      effects.from_promise(browser.activate_new_worker, WorkerActivated),
    )
    // The new worker takes over and fires ControllerChanged, which reloads.
    // ponytail: if its install fails nothing reloads; Reload stays on screen
    // and a second press tries again. Add a timeout if that ever bites.
    WorkerActivated(True) -> #(model, effect.none())
    WorkerActivated(False) -> #(model, reload())
    // A worker also takes over on the very first visit; reload only on request.
    ControllerChanged ->
      case model.update {
        Applying -> #(model, reload())
        UpToDate | Available -> #(model, effect.none())
      }
    // Remember where the screen being left was scrolled to, and go back to
    // where the next one was, or to its top.
    HashChanged(hash:, left_at:) -> {
      let scroll =
        dict.insert(model.scroll, route.to_hash(model.route), left_at)
      let next = route.parse(hash)
      let top = dict.get(scroll, route.to_hash(next)) |> result.unwrap(0.0)
      #(
        Model(
          ..model,
          route: next,
          scroll:,
          notes: notes.screen_changed(model.notes),
        ),
        scroll_to(top),
      )
    }
    NotesMsg(msg) -> {
      let #(state, done) = notes.update(model.notes, msg, model.storage)
      #(Model(..model, notes: state), effect.map(done, NotesMsg))
    }
  }
}

fn update_after_fetch(model: Model, fetched: Result(String, String)) -> Update {
  let running = version.parse(model.running)
  let latest =
    result.try(fetched, fn(text) {
      version.from_json(text) |> result.replace_error("")
    })
  case model.update, running, latest {
    UpToDate, Ok(running), Ok(latest) ->
      case version.is_newer(latest, than: running) {
        True -> Available
        False -> UpToDate
      }
    current, _, _ -> current
  }
}

/// When this device first opened the app, recorded now if this is the first time.
fn load_first_opened(db: Database) -> Promise(Result(Int, StorageError)) {
  use stored <- promise.try_await(storage.get(
    db,
    storage.Meta,
    first_opened_key,
    decode.int,
  ))
  case stored {
    Some(ms) -> promise.resolve(Ok(ms))
    None -> {
      let now = browser.now_ms()
      storage.put(db, storage.Meta, first_opened_key, json.int(now))
      |> promise.map(result.replace(_, now))
    }
  }
}

fn check_version() -> Effect(Msg) {
  effects.from_promise(
    fn() { browser.fetch_no_store("version.json") },
    VersionFetched,
  )
}

fn listen() -> Effect(Msg) {
  use dispatch <- effect.from
  browser.register_worker("sw.js")
  browser.on_visibility_change(fn(state) { dispatch(VisibilityChanged(state)) })
  browser.on_controller_change(fn() { dispatch(ControllerChanged) })
  browser.manual_scroll_restoration()
  route.on_hash_change(fn(hash) {
    dispatch(HashChanged(hash:, left_at: browser.scroll_y()))
  })
}

fn scroll_to(y: Float) -> Effect(Msg) {
  use _, _ <- effect.before_paint
  browser.scroll_to(y)
}

fn reload() -> Effect(Msg) {
  use _ <- effect.from
  browser.reload()
}

// --- Views ------------------------------------------------------------------

pub fn view(model: Model) -> Element(Msg) {
  let page = case model.route {
    route.Home -> home(model)
    route.NotePage(note_id:) ->
      notes.note_page(model.notes, note_id) |> notes_view
  }
  html.main(
    [attribute.class("page")],
    list.flatten([
      // First on every screen, so the person sees it without scrolling.
      [
        html.p([attribute.class("version-line")], [
          html.text("Version " <> model.running),
        ]),
      ],
      page,
      [update_bar(model.update)],
    ]),
  )
}

fn notes_view(elements: List(Element(notes.Msg))) -> List(Element(Msg)) {
  list.map(elements, element.map(_, NotesMsg))
}

/// The home screen: the app's name, each feature's part, and "About this
/// device".
fn home(model: Model) -> List(Element(Msg)) {
  // Nothing on this screen can read or save, so one message stands in for
  // every feature.
  use <- bool.lazy_guard(
    model.storage == Some(Error(storage.AppOlderThanData)),
    fn() {
      [
        html.h1([], [html.text(name)]),
        html.p([attribute.class("problem"), attribute.role("alert")], [
          html.text(
            "This is an older version of the app than the data saved on this device. Tap Reload below. If there is no Reload, close the app fully and open it again. Nothing saved on this device was lost.",
          ),
        ]),
        about(model),
      ]
    },
  )
  list.flatten([
    [html.h1([], [html.text(name)])],
    notes_view(notes.home(model.notes)),
    [about(model)],
  ])
}

fn about(model: Model) -> Element(Msg) {
  html.section([attribute.class("about")], [
    html.h2([], [html.text("About this device")]),
    html.dl([], [
      fact("Version", model.running),
      fact("Commit", model.commit),
      fact("Storage", storage_label(model.storage)),
      fact("Persistent storage", persistence_label(model.persistence)),
      fact(
        "First opened on this device",
        first_opened_label(model.first_opened),
      ),
    ]),
  ])
}

fn fact(term: String, detail: String) -> Element(Msg) {
  html.div([], [
    html.dt([], [html.text(term)]),
    html.dd([], [html.text(detail)]),
  ])
}

fn update_bar(update: Update) -> Element(Msg) {
  case update {
    UpToDate -> element.none()
    Available | Applying ->
      html.div([attribute.class("update-bar"), attribute.role("status")], [
        html.span([], [html.text("New version")]),
        html.button([attribute.type_("button"), event.on_click(ReloadClicked)], [
          html.text("Reload"),
        ]),
      ])
  }
}

fn storage_label(storage: Option(Result(Database, StorageError))) -> String {
  case storage {
    None -> "Opening…"
    Some(Ok(_)) -> "Open"
    Some(Error(error)) -> storage.describe_error(error)
  }
}

fn persistence_label(persistence: Option(Persistence)) -> String {
  case persistence {
    None -> "Asking the browser…"
    Some(storage.Persistent) -> "Granted"
    Some(storage.NotPersistent) ->
      "Not granted. The browser may clear saved data when space runs low."
    Some(storage.PersistUnavailable) -> "Not available in this browser"
  }
}

fn first_opened_label(
  first_opened: Option(Result(Int, StorageError)),
) -> String {
  case first_opened {
    None -> "Reading…"
    Some(Ok(ms)) -> browser.local_time(ms)
    Some(Error(error)) -> "Unknown. " <> storage.describe_error(error)
  }
}
