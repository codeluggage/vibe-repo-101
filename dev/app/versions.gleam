//// `gleam run -m app/versions [digits]` lists the versions that went
//// live, newest first, each with the first line of what changed: the newest
//// commit under its tag that is not a merge and not a `publish again`. With
//// digits
//// it lists the versions that match what a person said: `1542` is a version
//// made at 15:42, and `342` one made at 03:42 or 15:42.

import app/publish
import app/version
import gleam/int
import gleam/io
import gleam/javascript/array.{type Array}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub fn main() -> Nil {
  case run("git", ["fetch", "--quiet", "--tags", "origin"]) {
    Ok(#(0, _, _)) -> Nil
    _ ->
      io.println(
        "GitHub could not be reached, so the newest versions may be missing.",
      )
  }
  let listed =
    run("git", [
      "for-each-ref",
      "refs/tags",
      "--format=%(refname:short)%09%(parent)%09%(subject)",
    ])
  case listed, string.concat(array.to_list(arguments())) {
    Ok(#(0, out, _)), said -> {
      let versions = read_tags(out)
      let found = list.filter(versions, fn(found) { matches(found.0, said) })
      case versions, said, found {
        [], _, _ -> io.println("No version has gone live yet.")
        _, "", _ -> print(list.take(versions, 10))
        _, _, [] -> {
          io.println("No version matches " <> said <> ". The newest are:")
          print(list.take(versions, 10))
        }
        _, _, found -> print(found)
      }
    }
    _, _ -> {
      io.println("The versions could not be read.")
      set_exit_code(1)
    }
  }
}

/// The versions among the tags, newest first, from lines of
/// `<tag>\t<its commit's parents>\t<first line of its commit message>`, each
/// with that line, or None when the commit says nothing about what changed:
/// a merge, which has two parents, or the empty commit publish makes to send
/// the same work once more. Other tags are left out.
pub fn read_tags(text: String) -> List(#(String, Option(String))) {
  string.split(text, "\n")
  |> list.filter_map(fn(line) {
    use #(tag, rest) <- result.try(string.split_once(line, "\t"))
    use #(parents, subject) <- result.try(string.split_once(rest, "\t"))
    use _ <- result.map(version.parse(tag))
    case
      string.contains(string.trim(parents), " ") || subject == publish.again
    {
      True -> #(tag, None)
      False -> #(tag, Some(subject))
    }
  })
  |> list.sort(fn(a, b) { string.compare(b.0, a.0) })
}

/// Whether `version` is one a person meant by `said`. Only the digits count,
/// and the version's digits must end with them. Three or four digits are a
/// time of day that may be before or after noon: `342` and `0342` are 03:42
/// or 15:42, `1542` is only 15:42.
pub fn matches(version: String, said: String) -> Bool {
  let own = digits(version)
  let said = digits(said)
  case string.length(said) {
    0 -> False
    3 | 4 -> list.any(times(said), string.ends_with(own, _))
    _ -> string.ends_with(own, said)
  }
}

fn times(said: String) -> List(String) {
  let minute = string.slice(said, -2, 2)
  case int.parse(string.drop_end(said, 2)) {
    Ok(hour) if hour <= 12 -> [hour % 12, hour % 12 + 12]
    Ok(hour) -> [hour]
    Error(Nil) -> []
  }
  |> list.map(fn(hour) {
    string.pad_start(int.to_string(hour), 2, "0") <> minute
  })
}

fn digits(text: String) -> String {
  string.to_graphemes(text)
  |> list.filter(string.contains("0123456789", _))
  |> string.concat
}

fn print(versions: List(#(String, Option(String)))) -> Nil {
  list.each(versions, fn(found) {
    let changed = case found.1 {
      Some(subject) -> subject
      None -> newest_change(found.0)
    }
    io.println(found.0 <> "  " <> changed)
  })
}

/// The first line of the newest commit under `tag` that is not a merge and
/// not a `publish again`.
fn newest_change(tag: String) -> String {
  let skip = "--grep=^" <> publish.again <> "$"
  let args = ["log", "-1", "--no-merges", "--invert-grep", skip, "--format=%s"]
  case run("git", list.append(args, [tag])) {
    Ok(#(0, out, _)) -> string.trim(out)
    _ -> ""
  }
}

@external(javascript, "./node_ffi.mjs", "run")
fn run(
  program: String,
  args: List(String),
) -> Result(#(Int, String, String), String)

@external(javascript, "./node_ffi.mjs", "arguments_")
fn arguments() -> Array(String)

@external(javascript, "./node_ffi.mjs", "set_exit_code")
fn set_exit_code(code: Int) -> Nil
