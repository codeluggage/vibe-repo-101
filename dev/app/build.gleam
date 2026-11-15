//// `gleam run -m app/build` writes the site to `dist/`: the shell from
//// `web/`, every compiled module the app imports under `dist/js/`, and
//// `version.json`. The version is stamped into the page, `version.json` and
//// the service worker's cache name, the commit into the page, and the service
//// worker gets the list of files to keep for offline use.

import app/storage
import app/version.{type Version}
import gleam/dict
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import gleam/set.{type Set}
import gleam/string
import simplifile

const compiled = "build/dev/javascript"

const web = "web"

const dist = "dist"

const entry = "app/app.mjs"

/// The clock a version is read from: the minute of the build on this clock.
/// Any IANA time zone name works, such as "Europe/London" or
/// "America/New_York", so the version a person sees can match their watch.
const zone = "UTC"

pub type BuildError {
  FileFailed(path: String, error: simplifile.FileError)
  ImportOutsideRoot(importer: String, specifier: String)
  MissingStamp(file: String, stamp: String)
  NoVersion
}

pub fn main() -> Nil {
  let _ = write_site()
  Nil
}

/// Writes the site to `dist/` and says how that went. The version on success.
pub fn write_site() -> Result(String, Nil) {
  case build() {
    Ok(stamp) -> {
      io.println("Built dist/ at version " <> stamp)
      Ok(stamp)
    }
    Error(error) -> {
      io.println_error("Build failed: " <> describe(error))
      set_exit_code(1)
      Error(Nil)
    }
  }
}

fn build() -> Result(String, BuildError) {
  let commit = case run("git", ["rev-parse", "--short", "HEAD"]) {
    Ok(#(0, out, _)) -> string.trim(out)
    _ -> {
      io.println_error("No git commit found, the commit says nogit.")
      "nogit"
    }
  }
  use release <- result.try(
    release_at(now_ms()) |> result.replace_error(NoVersion),
  )
  let stamp = version.to_string(release)
  use _ <- result.try(simplifile.delete_all([dist]) |> on_file(dist))
  use modules <- result.try(module_graph(entry, read_compiled))
  use _ <- result.try(
    list.try_each(modules, fn(module) {
      copy(compiled <> "/" <> module, dist <> "/js/" <> module)
    }),
  )
  use shell <- result.try(
    files_under(web, skip: string.starts_with(_, "."))
    |> on_file(web),
  )
  let files =
    json.array(precache(shell, modules), json.string) |> json.to_string
  use _ <- result.try(
    list.try_each(shell, fn(file) {
      let from = web <> "/" <> file
      let to = dist <> "/" <> file
      case file {
        "index.html" ->
          stamp_file(from, to, [
            #("__VERSION__", stamp),
            #("__COMMIT__", commit),
          ])
        "sw.js" ->
          stamp_file(from, to, [#("__VERSION__", stamp), #("__FILES__", files)])
        _ -> copy(from, to)
      }
    }),
  )
  let json =
    version.Stamp(release:, commit:, schema: storage.schema_version())
    |> version.to_json
  use _ <- result.try(write(dist <> "/version.json", json))
  Ok(stamp)
}

/// The version of a build made at `ms`: its minute on the clock of `zone`.
pub fn release_at(ms: Int) -> Result(Version, Nil) {
  let part = clock(ms, zone)
  version.parse(
    part("year")
    <> "."
    <> part("month")
    <> "."
    <> part("day")
    <> "."
    <> part("hour")
    <> part("minute"),
  )
}

/// Each part of the instant `ms` on the wall clock of `zone` by its name, such
/// as `"hour"`, two digits from 00 to 23.
fn clock(ms: Int, zone: String) -> fn(String) -> String {
  let parts = dict.from_list(zoned_parts(ms, zone))
  fn(name) { dict.get(parts, name) |> result.unwrap("") }
}

/// What the service worker keeps for offline use, as URLs relative to it:
/// the start page, the shell (not the worker itself) and the modules.
pub fn precache(shell: List(String), modules: List(String)) -> List(String) {
  let shell = list.filter(shell, fn(file) { file != "sw.js" })
  let modules = list.map(modules, fn(module) { "js/" <> module })
  ["./", ..list.sort(list.append(shell, modules), string.compare)]
}

/// Replace each placeholder in `text`. A placeholder that is not there is an
/// error, so a template edit cannot quietly drop the version.
pub fn stamp(
  text: String,
  values: List(#(String, String)),
) -> Result(String, String) {
  list.try_fold(values, text, fn(text, pair) {
    let #(placeholder, value) = pair
    case string.contains(text, placeholder) {
      True -> Ok(string.replace(text, placeholder, value))
      False -> Error(placeholder)
    }
  })
}

/// Every module reachable from `entry` through relative imports, as paths
/// relative to the compiled tree, sorted.
pub fn module_graph(
  entry: String,
  read: fn(String) -> Result(String, BuildError),
) -> Result(List(String), BuildError) {
  walk([entry], set.new(), read)
  |> result.map(fn(seen) { set.to_list(seen) |> list.sort(string.compare) })
}

fn walk(
  queue: List(String),
  seen: Set(String),
  read: fn(String) -> Result(String, BuildError),
) -> Result(Set(String), BuildError) {
  case queue {
    [] -> Ok(seen)
    [path, ..rest] ->
      case set.contains(seen, path) {
        True -> walk(rest, seen, read)
        False -> {
          use source <- result.try(read(path))
          use imports <- result.try(
            list.try_map(import_specifiers(source), resolve(path, _)),
          )
          walk(list.append(imports, rest), set.insert(seen, path), read)
        }
      }
  }
}

/// The relative specifiers in a module's `import` and `export ... from`
/// statements. Bare names such as `node:fs` are left out.
pub fn import_specifiers(source: String) -> List(String) {
  // ponytail: a text scan, not a JS parser. Enough for the compiler's output
  // and the packages' FFI files; an import it finds but cannot read fails the
  // build. Swap for a parser if a package ever hides an import from it.
  [
    #("from \"", "\""),
    #("from '", "'"),
    #("import \"", "\""),
    #("import '", "'"),
    #("import(\"", "\""),
    #("import('", "'"),
  ]
  |> list.flat_map(fn(marker) {
    let #(start, quote) = marker
    string.split(source, start)
    |> list.drop(1)
    |> list.filter_map(fn(after) {
      string.split_once(after, quote) |> result.map(fn(pair) { pair.0 })
    })
  })
  |> list.filter(fn(specifier) {
    string.starts_with(specifier, "./") || string.starts_with(specifier, "../")
  })
  |> list.unique
}

/// The path `specifier` names when `importer` imports it.
pub fn resolve(
  importer: String,
  specifier: String,
) -> Result(String, BuildError) {
  let directory = string.split(importer, "/") |> list.reverse |> list.drop(1)
  string.split(specifier, "/")
  |> list.try_fold(directory, fn(reversed, segment) {
    case segment, reversed {
      ".", _ -> Ok(reversed)
      "..", [_, ..parent] -> Ok(parent)
      "..", [] -> Error(ImportOutsideRoot(importer:, specifier:))
      name, _ -> Ok([name, ..reversed])
    }
  })
  |> result.map(fn(reversed) { list.reverse(reversed) |> string.join("/") })
}

/// Every file under `root` as a `/`-separated path relative to it, leaving out
/// any file or folder whose relative path `skip` picks.
pub fn files_under(
  root: String,
  skip skip: fn(String) -> Bool,
) -> Result(List(String), simplifile.FileError) {
  files_in(root, "", skip)
}

fn files_in(
  root: String,
  relative: String,
  skip: fn(String) -> Bool,
) -> Result(List(String), simplifile.FileError) {
  use names <- result.try(simplifile.read_directory(join(root, relative)))
  names
  |> list.map(join(relative, _))
  |> list.filter(fn(path) { !skip(path) })
  |> list.try_map(fn(path) {
    use is_directory <- result.try(simplifile.is_directory(join(root, path)))
    case is_directory {
      True -> files_in(root, path, skip)
      False -> Ok([path])
    }
  })
  |> result.map(list.flatten)
}

fn join(directory: String, name: String) -> String {
  case directory {
    "" -> name
    _ -> directory <> "/" <> name
  }
}

fn read_compiled(module: String) -> Result(String, BuildError) {
  let path = compiled <> "/" <> module
  simplifile.read(path) |> on_file(path)
}

fn stamp_file(
  from: String,
  to: String,
  values: List(#(String, String)),
) -> Result(Nil, BuildError) {
  use text <- result.try(simplifile.read(from) |> on_file(from))
  use text <- result.try(
    stamp(text, values) |> result.map_error(MissingStamp(file: from, stamp: _)),
  )
  write(to, text)
}

fn copy(from: String, to: String) -> Result(Nil, BuildError) {
  use _ <- result.try(make_parent(to))
  simplifile.copy_file(from, to) |> on_file(from)
}

fn write(to: String, text: String) -> Result(Nil, BuildError) {
  use _ <- result.try(make_parent(to))
  simplifile.write(to, text) |> on_file(to)
}

fn make_parent(path: String) -> Result(Nil, BuildError) {
  let parent =
    string.split(path, "/") |> list.reverse |> list.drop(1) |> list.reverse
  simplifile.create_directory_all(string.join(parent, "/")) |> on_file(path)
}

fn on_file(
  outcome: Result(a, simplifile.FileError),
  path: String,
) -> Result(a, BuildError) {
  result.map_error(outcome, FileFailed(path, _))
}

fn describe(error: BuildError) -> String {
  case error {
    FileFailed(path, error) -> path <> ": " <> simplifile.describe_error(error)
    ImportOutsideRoot(importer, specifier) ->
      importer <> " imports " <> specifier <> ", outside " <> compiled
    MissingStamp(file, stamp) -> file <> " has no " <> stamp <> " to replace"
    NoVersion -> "the clock gave no valid version"
  }
}

@external(javascript, "./node_ffi.mjs", "now_ms")
fn now_ms() -> Int

@external(javascript, "./node_ffi.mjs", "zoned_parts")
fn zoned_parts(ms: Int, zone: String) -> List(#(String, String))

@external(javascript, "./node_ffi.mjs", "run")
fn run(
  program: String,
  args: List(String),
) -> Result(#(Int, String, String), String)

@external(javascript, "./node_ffi.mjs", "set_exit_code")
fn set_exit_code(code: Int) -> Nil
