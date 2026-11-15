//// Effects that the shell and more than one feature make.

import gleam/javascript/promise.{type Promise}
import lustre/effect.{type Effect}

/// Run the promise, then send its value as a message.
pub fn from_promise(
  run: fn() -> Promise(a),
  to_msg: fn(a) -> msg,
) -> Effect(msg) {
  use dispatch <- effect.from
  let _ = promise.tap(run(), fn(value) { dispatch(to_msg(value)) })
  Nil
}
