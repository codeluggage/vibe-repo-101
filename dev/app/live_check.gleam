//// `gleam run -m app/live_check` says whether the site in `dist/` may
//// replace the live one. Run it after the build and before a deploy. It exits
//// 0 when the new version may go live, and 1 with the reason when it may not.

import app/site
import app/version.{type Stamp}
import gleam/int
import gleam/io
import gleam/javascript/promise
import gleam/result
import simplifile

const built = "dist/version.json"

pub fn main() -> Nil {
  case read_built(), site.origin() {
    Error(reason), _ | _, Error(reason) -> refuse(reason)
    Ok(new), Ok(repository) -> {
      let _ = {
        use live <- promise.map(site.live_version(repository))
        case decide(new, live) {
          MayGoLive(sentence) -> io.println(sentence)
          NotLater(sentence) | OlderLayout(sentence) | CannotTell(sentence) ->
            refuse(sentence)
        }
      }
      Nil
    }
  }
}

/// The live check's answer, each with one sentence that says what was found.
/// Only `MayGoLive` lets the site go live.
pub type Verdict {
  MayGoLive(String)
  /// The new version is the live one or older.
  NotLater(String)
  /// The new version keeps saved data at a lower storage schema number.
  OlderLayout(String)
  /// The live version could not be read.
  CannotTell(String)
}

/// May the site stamped `new` replace the live one? `live` is the answer to
/// the request for the live `version.json`: #(HTTP status, body).
pub fn decide(new: Stamp, live: Result(#(Int, String), String)) -> Verdict {
  let release = version.to_string(new.release)
  case live {
    Error(reason) ->
      CannotTell("The live version could not be read: " <> reason)
    Ok(#(404, _)) ->
      MayGoLive(
        "There is no live site yet, so version " <> release <> " may go live.",
      )
    Ok(#(200, body)) ->
      case version.stamp_from_json(body) {
        Error(Nil) ->
          CannotTell("The live version.json is not one this check reads.")
        Ok(live) -> {
          let live_release = version.to_string(live.release)
          case
            new.schema < live.schema,
            version.is_newer(new.release, than: live.release)
          {
            False, False ->
              NotLater(
                "Version "
                <> release
                <> " is not later than the live version "
                <> live_release
                <> ", so it may not replace it.",
              )
            True, _ ->
              OlderLayout(
                "Version "
                <> release
                <> " keeps saved data in an older layout ("
                <> int.to_string(new.schema)
                <> ") than the live version "
                <> live_release
                <> " ("
                <> int.to_string(live.schema)
                <> "), so it may not replace it.",
              )
            False, True ->
              MayGoLive(
                "Version "
                <> release
                <> " may replace the live version "
                <> live_release
                <> ".",
              )
          }
        }
      }
    Ok(#(status, _)) ->
      CannotTell(
        "The live site answered "
        <> int.to_string(status)
        <> " when asked for its version.json.",
      )
  }
}

/// The stamp of the site the build wrote to `dist/`.
pub fn read_built() -> Result(Stamp, String) {
  simplifile.read(built)
  |> result.replace_error(Nil)
  |> result.try(version.stamp_from_json)
  |> result.replace_error(
    built <> " has no version. Run gleam run -m app/build first.",
  )
}

fn refuse(sentence: String) -> Nil {
  io.println_error(sentence)
  set_exit_code(1)
}

@external(javascript, "./node_ffi.mjs", "set_exit_code")
fn set_exit_code(code: Int) -> Nil
