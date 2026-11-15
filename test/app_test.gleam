import app.{
  type Model, Applying, Available, Flags, HashChanged, Model, NotesMsg,
  StorageOpened, UpToDate, VersionFetched,
}
import app/notes
import app/route
import app/storage
import gleam/dict
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import lustre/element

pub fn main() -> Nil {
  gleeunit.main()
}

const running = "2026.11.12.2041"

const commit = "aaaaaaa"

fn model(update: app.Update) -> Model {
  let #(model, _) = app.init(Flags(running:, commit:, hash: ""))
  Model(..model, update:)
}

fn fetched(model: Model, body: Result(String, String)) -> app.Update {
  let #(model, _) = app.update(model, VersionFetched(body))
  model.update
}

fn release(text: String) -> Result(String, String) {
  Ok("{\"release\":\"" <> text <> "\",\"commit\":\"bbbbbbb\",\"schema\":1}")
}

pub fn newer_release_offers_a_reload_test() {
  assert fetched(model(UpToDate), release("2026.11.12.2042")) == Available
}

pub fn same_or_older_release_offers_nothing_test() {
  assert fetched(model(UpToDate), release(running)) == UpToDate
  assert fetched(model(UpToDate), release("2026.11.11.2359")) == UpToDate
}

pub fn failed_or_foreign_fetch_offers_nothing_test() {
  assert fetched(model(UpToDate), Error("offline")) == UpToDate
  assert fetched(model(UpToDate), Ok("<!doctype html>Not found")) == UpToDate
}

pub fn unstamped_page_offers_nothing_test() {
  let #(unstamped, _) =
    app.init(Flags(running: "__VERSION__", commit: "__COMMIT__", hash: ""))
  assert fetched(unstamped, release("2026.11.13.0800")) == UpToDate
}

pub fn a_reload_in_progress_stays_in_progress_test() {
  assert fetched(model(Applying), release("2026.11.11.2041")) == Applying
}

pub fn every_screen_starts_with_the_version_test() {
  let line =
    "<main class=\"page\"><p class=\"version-line\">Version 2026.11.12.2041</p>"
  let home = app.view(model(UpToDate)) |> element.to_string
  assert string.starts_with(home, line)
  let note =
    app.view(Model(..model(UpToDate), route: route.NotePage("gone")))
    |> element.to_string
  assert string.starts_with(note, line)
}

pub fn the_update_bar_offers_a_reload_test() {
  let bar = "<span>New version</span><button type=\"button\">Reload</button>"
  assert !string.contains(app.view(model(UpToDate)) |> element.to_string, bar)
  assert string.contains(app.view(model(Available)) |> element.to_string, bar)
}

pub fn the_home_screen_has_the_name_notes_and_about_test() {
  let home = app.view(model(UpToDate)) |> element.to_string
  let assert [_, after_name] = string.split(home, "<h1>My app</h1>")
  let assert [_, after_notes] = string.split(after_name, "<h2>Notes</h2>")
  assert string.contains(after_notes, "<h2>About this device</h2>")
}

pub fn about_this_device_shows_the_version_and_commit_test() {
  let home = app.view(model(UpToDate)) |> element.to_string
  assert string.contains(home, "<dt>Version</dt><dd>2026.11.12.2041</dd>")
  assert string.contains(home, "<dt>Commit</dt><dd>aaaaaaa</dd>")
}

pub fn the_screen_starts_from_the_hash_test() {
  let #(model, _) = app.init(Flags(running:, commit:, hash: "#/note/abc"))
  assert model.route == route.NotePage("abc")
}

pub fn a_hash_change_moves_screens_and_remembers_the_scroll_test() {
  let #(model, _) =
    app.update(model(UpToDate), HashChanged("#/note/abc", 120.0))
  assert model.route == route.NotePage("abc")
  assert dict.get(model.scroll, "#/") == Ok(120.0)
}

pub fn a_screen_change_clears_the_notes_problem_test() {
  let #(asking, _) =
    app.update(
      model(UpToDate),
      NotesMsg(notes.NoteSaved(Error(storage.WriteFailed("full")))),
    )
  assert asking.notes.problem
    == Some(notes.NotSaved(storage.WriteFailed("full")))
  let #(moved, _) = app.update(asking, HashChanged("#/note/abc", 0.0))
  assert moved.notes.problem == None
}

pub fn the_notes_screen_shows_a_saved_note_test() {
  let note = notes.Note(id: "abc", text: "Buy milk", added: 0)
  let #(model, _) =
    app.update(model(UpToDate), NotesMsg(notes.NotesLoaded(Ok([note]))))
  let page =
    app.view(Model(..model, route: route.NotePage("abc")))
    |> element.to_string
  assert string.contains(page, "<p class=\"prose\">Buy milk</p>")
}

pub fn an_app_older_than_the_data_says_so_once_on_the_home_screen_test() {
  let message =
    "This is an older version of the app than the data saved on this device. Tap Reload below. If there is no Reload, close the app fully and open it again. Nothing saved on this device was lost."
  let older = storage.AppOlderThanData
  let #(opened, _) = app.update(model(UpToDate), StorageOpened(Error(older)))
  // What the notes read when storage did not open.
  let #(opened, _) =
    app.update(opened, NotesMsg(notes.NotesLoaded(Error(older))))
  let home = app.view(opened) |> element.to_string
  let assert [before, after] = string.split(home, message)
  assert string.ends_with(
    before,
    "<h1>My app</h1><p class=\"problem\" role=\"alert\">",
  )
  assert !string.contains(after, "could not be read")
  assert !string.contains(after, "<h2>Notes</h2>")
  assert string.contains(after, "<h2>About this device</h2>")
  // Any other failure to open keeps its words and the features.
  let #(other, _) =
    app.update(
      model(UpToDate),
      StorageOpened(Error(storage.OpenFailed("UnknownError: gone"))),
    )
  let home = app.view(other) |> element.to_string
  assert !string.contains(home, message)
  assert string.contains(home, "Could not open. UnknownError: gone")
  assert string.contains(home, "<h2>Notes</h2>")
}
