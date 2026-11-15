//// The screen lives in the URL hash, so the back button steps through screens
//// and a reload keeps the screen. Links are plain `<a href="#/...">`, which
//// stay relative to the page wherever the site is served.

import gleam/list
import gleam/string
import gleam/uri

pub type Route {
  /// `#/`: the home screen.
  Home
  /// `#/note/<note id>`: one note.
  NotePage(note_id: String)
}

/// The route for a `location.hash`. Anything unknown is `Home`.
pub fn parse(hash: String) -> Route {
  let path = case hash {
    "#/" <> path -> path
    "#" <> path -> path
    path -> path
  }
  let parts =
    string.split(path, "/")
    |> list.try_map(fn(part) {
      case uri.percent_decode(part) {
        Ok("") -> Error(Nil)
        decoded -> decoded
      }
    })
  case parts {
    Ok(["note", note_id]) -> NotePage(note_id:)
    _ -> Home
  }
}

pub fn to_hash(route: Route) -> String {
  let parts = case route {
    Home -> []
    NotePage(note_id:) -> ["note", note_id]
  }
  "#/" <> { list.map(parts, uri.percent_encode) |> string.join("/") }
}

/// `location.hash` now.
@external(javascript, "./browser_ffi.mjs", "current_hash")
pub fn current_hash() -> String

/// Calls back with `location.hash` each time it changes.
@external(javascript, "./browser_ffi.mjs", "on_hash_change")
pub fn on_hash_change(callback: fn(String) -> Nil) -> Nil
