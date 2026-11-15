//// The browser's IndexedDB behind promises of `Result`. A value goes in as
//// JSON that Gleam encodes and decodes, which the database sees as a string.
////
//// The schema is `upgrades`: step n creates the stores that schema version n
//// adds. "Adding a store" in AGENTS.md says how to add one.
////
//// IndexedDB is shared by every page of one origin, and many sites share one
//// origin, such as `https://<owner>.github.io/<repository>/`. So the database
//// is named after the folder of the page, and each site keeps its own.

import app/browser
import gleam/bool
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/javascript/promise.{type Promise}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

pub type Database

pub type Store {
  /// App metadata, one record per key, such as when the app was first opened.
  Meta
  /// The notes, one record per note, keyed by a random id.
  Notes
}

/// One change in a `write`.
pub type Write {
  Put(store: Store, key: String, value: json.Json)
  Remove(store: Store, key: String)
}

pub type StorageError {
  /// A newer version of the app already upgraded the saved data, so this
  /// older one cannot open it. Nothing is lost.
  AppOlderThanData
  OpenFailed(reason: String)
  ReadFailed(reason: String)
  WriteFailed(reason: String)
  DeleteFailed(reason: String)
  Undecodable(key: String)
}

/// The browser's answer to "keep this site's data when space runs low".
pub type Persistence {
  Persistent
  NotPersistent
  PersistUnavailable
}

/// Oldest first. Step n moves a database from schema version n - 1 to n.
const upgrades: List(List(Store)) = [
  [Meta, Notes],
]

pub fn schema_version() -> Int {
  list.length(upgrades)
}

/// The stores to create when a database at `old_version` opens: every store
/// that a later step adds. A database that does not exist yet is at 0.
pub fn stores_to_create(from old_version: Int) -> List(String) {
  upgrades
  |> list.drop(old_version)
  |> list.flatten
  |> list.map(store_name)
}

pub fn store_name(store: Store) -> String {
  case store {
    Meta -> "meta"
    Notes -> "notes"
  }
}

/// The database of the site a page belongs to: `app ` and the page's folder,
/// such as `app /my-game/` for `/my-game/` and `/my-game/index.html`.
pub fn database_name(page_path: String) -> String {
  let folders = string.split(page_path, "/") |> list.reverse |> list.drop(1)
  "app " <> string.join(list.reverse(folders), "/") <> "/"
}

pub fn open() -> Promise(Result(Database, StorageError)) {
  do_open(
    database_name(browser.page_path()),
    schema_version(),
    stores_to_create,
  )
  |> promise.map(result.map_error(_, open_error))
}

/// Why the database did not open, from the browser's error name and words.
pub fn open_error(failure: #(String, String)) -> StorageError {
  case failure {
    // The saved schema is later than this app's.
    #("VersionError", _) -> AppOlderThanData
    #(_, reason) -> OpenFailed(reason)
  }
}

/// `Ok(None)` when nothing is stored under `key`.
pub fn get(
  db: Database,
  store: Store,
  key: String,
  decoder: decode.Decoder(a),
) -> Promise(Result(Option(a), StorageError)) {
  do_get(db, store_name(store), key)
  |> promise.map(fn(raw) {
    use raw <- result.try(result.map_error(raw, ReadFailed))
    decode_value(raw, key, decoder)
  })
}

/// Resolves once the write is committed.
pub fn put(
  db: Database,
  store: Store,
  key: String,
  value: json.Json,
) -> Promise(Result(Nil, StorageError)) {
  write(db, [Put(store, key, value)])
}

/// Every change in one transaction over the stores they name: all are saved
/// or none. Resolves once the transaction is committed. The removes run
/// before the puts.
pub fn write(
  db: Database,
  writes: List(Write),
) -> Promise(Result(Nil, StorageError)) {
  commit(db, writes, WriteFailed)
}

fn commit(
  db: Database,
  writes: List(Write),
  failed: fn(String) -> StorageError,
) -> Promise(Result(Nil, StorageError)) {
  // A transaction over no store is an error in IndexedDB.
  use <- bool.guard(writes == [], promise.resolve(Ok(Nil)))
  let stores =
    list.map(writes, fn(write) { store_name(write.store) }) |> list.unique
  let puts =
    list.filter_map(writes, fn(write) {
      case write {
        Put(store:, key:, value:) ->
          Ok(#(store_name(store), key, json.to_string(value)))
        Remove(..) -> Error(Nil)
      }
    })
  let removes =
    list.filter_map(writes, fn(write) {
      case write {
        Remove(store:, key:) -> Ok(#(store_name(store), key))
        Put(..) -> Error(Nil)
      }
    })
  do_write(db, stores, puts, removes)
  |> promise.map(result.map_error(_, failed))
}

/// Every record in `store` with its key, in key order. A record that does not
/// decode comes back as an error of its own, so one bad record hides no other.
pub fn get_all(
  db: Database,
  store: Store,
  decoder: decode.Decoder(a),
) -> Promise(Result(List(#(String, Result(a, StorageError))), StorageError)) {
  do_get_all(db, store_name(store))
  |> promise.map(fn(raw) {
    use raw <- result.try(result.map_error(raw, ReadFailed))
    use pairs <- result.map(
      decode.run(raw, keys_and_values())
      |> result.replace_error(ReadFailed("The saved keys could not be read.")),
    )
    use #(key, value) <- list.map(pairs)
    #(key, case decode_value(value, key, decoder) {
      Ok(Some(value)) -> Ok(value)
      Ok(None) -> Error(Undecodable(key))
      Error(error) -> Error(error)
    })
  })
}

/// `get_all` hands back `[keys, values]`, two lists in the same order.
fn keys_and_values() -> decode.Decoder(List(#(String, Dynamic))) {
  use keys <- decode.field(0, decode.list(decode.string))
  use values <- decode.field(1, decode.list(decode.dynamic))
  decode.success(list.zip(keys, values))
}

/// Resolves once the delete is committed. Deleting a missing key is no error.
pub fn delete(
  db: Database,
  store: Store,
  key: String,
) -> Promise(Result(Nil, StorageError)) {
  commit(db, [Remove(store, key)], DeleteFailed)
}

pub fn persist() -> Promise(Persistence) {
  use answer <- promise.map(do_persist())
  case answer {
    Ok(True) -> Persistent
    Ok(False) -> NotPersistent
    Error(_) -> PersistUnavailable
  }
}

/// Decode what IndexedDB handed back for `key`: nothing, or a JSON string.
pub fn decode_value(
  raw: Dynamic,
  key: String,
  decoder: decode.Decoder(a),
) -> Result(Option(a), StorageError) {
  case decode.run(raw, decode.optional(decode.string)) {
    Ok(None) -> Ok(None)
    Ok(Some(text)) ->
      json.parse(text, decoder)
      |> result.map(Some)
      |> result.replace_error(Undecodable(key))
    Error(_) -> Error(Undecodable(key))
  }
}

/// A storage error in words, for any screen that shows one.
pub fn describe_error(error: StorageError) -> String {
  case error {
    AppOlderThanData -> "This app is older than the data saved on this device."
    OpenFailed(reason) -> "Could not open. " <> reason
    ReadFailed(reason) -> "Could not read. " <> reason
    WriteFailed(reason) -> "Could not save. " <> reason
    DeleteFailed(reason) -> "Could not delete. " <> reason
    Undecodable(key) -> "The saved " <> key <> " could not be read."
  }
}

@external(javascript, "./storage_ffi.mjs", "open")
fn do_open(
  name: String,
  version: Int,
  stores_to_create: fn(Int) -> List(String),
) -> Promise(Result(Database, #(String, String)))

@external(javascript, "./storage_ffi.mjs", "get")
fn do_get(
  db: Database,
  store: String,
  key: String,
) -> Promise(Result(Dynamic, String))

/// `puts` are store, key and JSON text, `removes` are store and key.
@external(javascript, "./storage_ffi.mjs", "write")
fn do_write(
  db: Database,
  stores: List(String),
  puts: List(#(String, String, String)),
  removes: List(#(String, String)),
) -> Promise(Result(Nil, String))

@external(javascript, "./storage_ffi.mjs", "get_all")
fn do_get_all(db: Database, store: String) -> Promise(Result(Dynamic, String))

@external(javascript, "./storage_ffi.mjs", "persist")
fn do_persist() -> Promise(Result(Bool, String))
