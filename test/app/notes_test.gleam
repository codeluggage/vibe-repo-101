import app/notes.{
  AddSubmitted, DraftChanged, NoStorage, NotRemoved, NotSaved, Note, NoteRemoved,
  NoteSaved, NotesLoaded, RemoveClicked, State,
}
import app/storage
import gleam/json
import gleam/option.{None, Some}
import gleam/string
import lustre/element

const first = Note(id: "n1", text: "Buy milk", added: 1000)

const second = Note(id: "n2", text: "Call home", added: 2000)

fn loaded(list: List(notes.Note)) -> notes.State {
  State(..notes.init(), notes: Some(Ok(list)))
}

fn update(state: notes.State, msg: notes.Msg) -> notes.State {
  // No storage in a test: only what happens without it can be seen here.
  let #(state, _) =
    notes.update(state, msg, Some(Error(storage.OpenFailed("not in a test"))))
  state
}

pub fn newest_first_test() {
  assert notes.newest_first([first, second]) == [second, first]
  assert notes.newest_first([second, first]) == [second, first]
  assert notes.newest_first([]) == []
}

pub fn a_note_round_trips_through_its_record_test() {
  let record = notes.to_json(first) |> json.to_string
  assert record == "{\"text\":\"Buy milk\",\"added\":1000}"
  assert json.parse(record, notes.record_decoder()) == Ok(#("Buy milk", 1000))
}

pub fn typing_changes_the_draft_test() {
  let state = update(loaded([]), DraftChanged("Buy"))
  assert state.draft == "Buy"
}

pub fn a_blank_draft_adds_nothing_test() {
  let state = State(..loaded([]), draft: "   ")
  assert update(state, AddSubmitted) == state
}

pub fn without_storage_nothing_changes_and_it_says_why_test() {
  let state = State(..loaded([first]), draft: "Call home")
  let added = update(state, AddSubmitted)
  assert added.problem == Some(NoStorage)
  assert added.draft == "Call home"
  let removed = update(loaded([first]), RemoveClicked("n1"))
  assert removed.problem == Some(NoStorage)
  assert removed.notes == Some(Ok([first]))
}

pub fn a_saved_note_comes_first_and_clears_the_draft_test() {
  let state = State(..loaded([first]), draft: "Call home")
  let state = update(state, NoteSaved(Ok(second)))
  assert state.notes == Some(Ok([second, first]))
  assert state.draft == ""
}

pub fn a_failed_save_keeps_the_draft_test() {
  let error = storage.WriteFailed("full")
  let state = State(..loaded([]), draft: "Call home")
  let state = update(state, NoteSaved(Error(error)))
  assert state.draft == "Call home"
  assert state.problem == Some(NotSaved(error))
}

pub fn a_removed_note_goes_test() {
  let state = update(loaded([first, second]), NoteRemoved("n1", Ok(Nil)))
  assert state.notes == Some(Ok([second]))
  let error = storage.DeleteFailed("busy")
  let state = update(loaded([first]), NoteRemoved("n1", Error(error)))
  assert state.notes == Some(Ok([first]))
  assert state.problem == Some(NotRemoved(error))
}

pub fn a_screen_change_clears_the_problem_test() {
  let state = State(..loaded([]), problem: Some(NoStorage))
  assert notes.screen_changed(state).problem == None
}

fn home(state: notes.State) -> String {
  notes.home(state) |> element.fragment |> element.to_string
}

pub fn the_home_screen_lists_the_notes_newest_first_test() {
  let page = home(loaded([first, second]))
  let assert [_, after_second] = string.split(page, "Call home")
  assert string.contains(after_second, "Buy milk")
  assert string.contains(page, "href=\"#/note/n1\"")
  assert string.contains(page, ">Remove</button>")
  assert string.contains(page, "<label for=\"note-text\">New note</label>")
}

pub fn the_home_screen_says_when_there_are_no_notes_test() {
  assert string.contains(
    home(loaded([])),
    "No notes yet. Write one above and tap Add.",
  )
  assert string.contains(home(notes.init()), "Opening the notes…")
  let failed =
    update(notes.init(), NotesLoaded(Error(storage.Undecodable("n1"))))
  assert string.contains(
    home(failed),
    "The saved notes could not be read. The saved n1 could not be read.",
  )
}

fn page(state: notes.State, id: String) -> String {
  notes.note_page(state, id) |> element.fragment |> element.to_string
}

pub fn a_note_has_its_own_screen_with_a_way_back_test() {
  let found = page(loaded([first]), "n1")
  assert string.contains(found, "href=\"#/\"")
  assert string.contains(found, "All notes")
  assert string.contains(found, "<p class=\"prose\">Buy milk</p>")
  let missing = page(loaded([first]), "gone")
  assert string.contains(missing, "This note is not on this device.")
  assert string.contains(missing, "href=\"#/\"")
}
