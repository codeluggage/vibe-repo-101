//// `gleam run -m app/serve [port]` builds the site, then serves `dist/` on
//// localhost, port 8080 unless given.

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
          start_server(port, respond)
          io.println(
            "Serving dist/ at http://localhost:"
            <> int.to_string(port)
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

fn respond(url: String) -> #(Int, String, BitArray) {
  let found = {
    use path <- result.try(file_for(url))
    simplifile.read_bits(dist <> "/" <> path)
    |> result.map(fn(body) { #(path, body) })
    |> result.replace_error(Nil)
  }
  case found {
    Ok(#(path, body)) -> #(200, content_type(path), body)
    Error(Nil) -> #(
      404,
      "text/plain; charset=utf-8",
      bit_array.from_string("Not found"),
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
