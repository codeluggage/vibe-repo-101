//// `gleam run -m app/serve [port]` builds the site, then serves `dist/` on
//// localhost, port 8080 unless given.
////
//// The site is served under the project folder's name, such as
//// `http://localhost:8080/my-game/`, the way GitHub Pages serves it under the
//// repository's name. The browser keeps saved data per page folder, so two
//// projects on one port keep their data apart.

import app/build
import gleam/bit_array
import gleam/bool
import gleam/int
import gleam/io
import gleam/javascript/array.{type Array}
import gleam/list
import gleam/result
import gleam/string
import gleam/uri
import simplifile

const dist = "dist"

pub fn main() -> Nil {
  case port(array.to_list(arguments())) {
    Ok(port) ->
      case build.write_site() {
        Error(Nil) -> Nil
        Ok(_) -> {
          let site =
            simplifile.current_directory()
            |> result.unwrap("")
            |> site_name
          start_server(port, respond(site, _))
          io.println(
            "Serving dist/ at http://localhost:"
            <> int.to_string(port)
            <> "/"
            <> uri.percent_encode(site)
            <> "/ (Ctrl+C stops it)",
          )
        }
      }
    Error(Nil) -> {
      io.println_error("Usage: gleam run -m app/serve [port]")
      set_exit_code(1)
    }
  }
}

pub fn port(arguments: List(String)) -> Result(Int, Nil) {
  case arguments {
    [] -> Ok(8080)
    [text] ->
      case int.parse(text) {
        Ok(port) if port > 0 && port < 65_536 -> Ok(port)
        _ -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

/// The name of the project folder, from its full path on any system. It is
/// the site's sub-path on localhost.
pub fn site_name(directory: String) -> String {
  string.replace(directory, "\\", "/")
  |> string.split("/")
  |> list.filter(fn(s) { s != "" })
  |> list.last
  |> result.unwrap("app")
}

/// The file inside the site that `path` names, when `path` is under the
/// site's folder: `my-game/style.css` is `style.css` for the site `my-game`.
pub fn inside_site(site: String, path: String) -> Result(String, Nil) {
  case string.split_once(path, "/") {
    Ok(#(first, rest)) if first == site -> Ok(rest)
    _ -> Error(Nil)
  }
}

fn respond(site: String, url: String) -> #(Int, String, BitArray) {
  let inside = file_for(url) |> result.try(inside_site(site, _))
  let found = {
    use path <- result.try(inside)
    simplifile.read_bits(dist <> "/" <> path)
    |> result.map(fn(body) { #(path, body) })
    |> result.replace_error(Nil)
  }
  case inside, found {
    _, Ok(#(path, body)) -> #(200, content_type(path), body)
    Ok(_), Error(Nil) -> #(
      404,
      "text/plain; charset=utf-8",
      bit_array.from_string("Not found"),
    )
    // Outside the site's folder: send the browser into it.
    Error(Nil), _ -> #(
      200,
      "text/html; charset=utf-8",
      bit_array.from_string(
        "<!doctype html><meta http-equiv=\"refresh\" content=\"0; url=/"
        <> uri.percent_encode(site)
        <> "/\">",
      ),
    )
  }
}

/// The file under `dist/` that a request URL names. A folder means its
/// `index.html`. A path that climbs out of `dist/` names nothing.
pub fn file_for(url: String) -> Result(String, Nil) {
  use parsed <- result.try(uri.parse(url))
  use path <- result.try(uri.percent_decode(parsed.path))
  let segments = string.split(path, "/") |> list.filter(fn(s) { s != "" })
  let climbs =
    list.any(segments, fn(s) { s == ".." || string.contains(s, "\\") })
  use <- bool.guard(climbs, Error(Nil))
  case segments == [] || string.ends_with(path, "/") {
    True -> Ok(string.join(list.append(segments, ["index.html"]), "/"))
    False -> Ok(string.join(segments, "/"))
  }
}

pub fn content_type(path: String) -> String {
  case list.last(string.split(path, ".")) {
    Ok("html") -> "text/html; charset=utf-8"
    Ok("mjs") | Ok("js") -> "text/javascript; charset=utf-8"
    Ok("css") -> "text/css; charset=utf-8"
    Ok("json") -> "application/json"
    Ok("webmanifest") -> "application/manifest+json"
    Ok("png") -> "image/png"
    _ -> "application/octet-stream"
  }
}

@external(javascript, "./node_ffi.mjs", "arguments_")
fn arguments() -> Array(String)

@external(javascript, "./node_ffi.mjs", "set_exit_code")
fn set_exit_code(code: Int) -> Nil

@external(javascript, "./node_ffi.mjs", "start_server")
fn start_server(
  port: Int,
  respond: fn(String) -> #(Int, String, BitArray),
) -> Nil
