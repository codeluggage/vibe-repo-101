//// Where this project lives on GitHub, read from the `origin` remote: its
//// repository, and the live site GitHub Pages serves for it at
//// `https://<owner>.github.io/<repository>/`.

import gleam/int
import gleam/javascript/promise.{type Promise}
import gleam/result
import gleam/string

pub type Repository {
  Repository(owner: String, name: String)
}

/// The repository a remote address names, in the `https://github.com/o/r.git`
/// or `git@github.com:o/r.git` form, with `.git` at the end or without.
pub fn parse(remote: String) -> Result(Repository, Nil) {
  use path <- result.try(case string.trim(remote) {
    "https://github.com/" <> path
    | "git@github.com:" <> path
    | "ssh://git@github.com/" <> path -> Ok(path)
    _ -> Error(Nil)
  })
  let path = case string.ends_with(path, ".git") {
    True -> string.drop_end(path, 4)
    False -> path
  }
  case string.split(path, "/") {
    [owner, name] if owner != "" && name != "" -> Ok(Repository(owner:, name:))
    _ -> Error(Nil)
  }
}

/// The address of the live site, ending in `/`.
pub fn address(repository: Repository) -> String {
  "https://" <> repository.owner <> ".github.io/" <> repository.name <> "/"
}

/// The repository the `origin` remote of this copy names.
pub fn origin() -> Result(Repository, String) {
  case run("git", ["remote", "get-url", "origin"]) {
    Ok(#(0, remote, _)) ->
      parse(remote)
      |> result.replace_error(
        "The project's address " <> string.trim(remote) <> " is not on GitHub.",
      )
    Ok(#(_, _, error)) -> Error(string.trim(error))
    Error(reason) -> Error(reason)
  }
}

/// The live `version.json` as #(HTTP status, body), asked for with a query
/// string that no cache has seen, so the ten-minute cache cannot answer.
pub fn live_version(
  repository: Repository,
) -> Promise(Result(#(Int, String), String)) {
  fetch_text(
    address(repository) <> "version.json?fresh=" <> int.to_string(now_ms()),
  )
}

@external(javascript, "./node_ffi.mjs", "run")
fn run(
  program: String,
  args: List(String),
) -> Result(#(Int, String, String), String)

@external(javascript, "./node_ffi.mjs", "fetch_text")
fn fetch_text(url: String) -> Promise(Result(#(Int, String), String))

@external(javascript, "./node_ffi.mjs", "now_ms")
fn now_ms() -> Int
