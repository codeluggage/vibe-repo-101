//// The version a person can say: the minute a build was made, as
//// `2026.11.13.1542`, the year, month, day, hour and minute on one clock the
//// build picks. Always 15 characters, so the text sorts in time order.

import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/order
import gleam/result
import gleam/string

pub opaque type Version {
  Version(text: String)
}

/// What `version.json` says about a build.
pub type Stamp {
  Stamp(release: Version, commit: String, schema: Int)
}

pub fn parse(text: String) -> Result(Version, Nil) {
  case string.split(text, ".") {
    [year, month, day, time] ->
      case
        digits(year, 4) && digits(month, 2) && digits(day, 2) && digits(time, 4)
      {
        True -> Ok(Version(text))
        False -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

pub fn to_string(version: Version) -> String {
  version.text
}

/// True when `candidate` was built in a later minute than `running`. An older
/// or equal build is never offered as an update, which keeps a stale copy of
/// `version.json` from a slow cache from prompting a reload.
pub fn is_newer(candidate: Version, than running: Version) -> Bool {
  string.compare(candidate.text, running.text) == order.Gt
}

/// The contents of `version.json`.
pub fn to_json(stamp: Stamp) -> String {
  json.object([
    #("release", json.string(stamp.release.text)),
    #("commit", json.string(stamp.commit)),
    #("schema", json.int(stamp.schema)),
  ])
  |> json.to_string
}

/// The release a `version.json` names. The app reads only this key.
pub fn from_json(text: String) -> Result(Version, Nil) {
  let decoder = {
    use release <- decode.field("release", decode.string)
    decode.success(release)
  }
  json.parse(text, decoder) |> result.replace_error(Nil) |> result.try(parse)
}

/// Everything a `version.json` says.
pub fn stamp_from_json(text: String) -> Result(Stamp, Nil) {
  let decoder = {
    use release <- decode.field("release", decode.string)
    use commit <- decode.field("commit", decode.string)
    use schema <- decode.field("schema", decode.int)
    decode.success(#(release, commit, schema))
  }
  use #(release, commit, schema) <- result.try(
    json.parse(text, decoder) |> result.replace_error(Nil),
  )
  use release <- result.map(parse(release))
  Stamp(release:, commit:, schema:)
}

fn digits(text: String, count: Int) -> Bool {
  string.length(text) == count
  && list.all(string.to_graphemes(text), string.contains("0123456789", _))
}
