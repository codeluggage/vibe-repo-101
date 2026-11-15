// Node calls for the dev commands. No decisions here.
import { spawnSync } from "node:child_process";
import { createServer } from "node:http";
import { Result$Ok, Result$Error, BitArray$BitArray$data, toList } from "../gleam.mjs";

export function now_ms() {
  return Date.now();
}

// The date and time parts of the instant `ms` on the wall clock of `zone`,
// 24-hour, as a list of #(type, value) such as #("hour", "15").
export function zoned_parts(ms, zone) {
  const format = new Intl.DateTimeFormat("en-GB", {
    timeZone: zone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  });
  return toList(format.formatToParts(ms).map((part) => [part.type, part.value]));
}

// Runs `program` with the list `args`, never through a shell, and waits for
// it. #(exit status, stdout, stderr), or Error when it could not start. A
// program stopped by a signal has no status and gives -1.
export function run(program, args) {
  const out = spawnSync(program, args.toArray(), { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
  if (out.error) return Result$Error(String(out.error));
  return Result$Ok([out.status ?? -1, out.stdout, out.stderr]);
}

// #(HTTP status, body) of a GET, or Error when there was no answer.
export async function fetch_text(url) {
  try {
    const response = await fetch(url);
    return Result$Ok([response.status, await response.text()]);
  } catch (error) {
    return Result$Error(String(error));
  }
}

export function arguments_() {
  return process.argv.slice(2);
}

export function set_exit_code(code) {
  process.exitCode = code;
}

// `respond` is a Gleam fn(url) -> #(status, content_type, body).
export function start_server(port, respond) {
  createServer((request, response) => {
    const [status, type, body] = respond(request.url);
    const view = BitArray$BitArray$data(body);
    response.writeHead(status, { "content-type": type, "cache-control": "no-cache" });
    response.end(new Uint8Array(view.buffer, view.byteOffset, view.byteLength));
  }).listen(port);
}
