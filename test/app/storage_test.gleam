import app/storage.{Undecodable}
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/option.{None, Some}

pub fn schema_is_at_version_one_test() {
  assert storage.schema_version() == 1
}

pub fn a_new_database_gets_every_store_test() {
  assert storage.stores_to_create(from: 0) == ["meta", "notes"]
}

pub fn a_current_database_gets_no_store_test() {
  assert storage.stores_to_create(from: storage.schema_version()) == []
}

pub fn the_database_is_named_after_the_folder_of_the_page_test() {
  assert storage.database_name("/my-game/") == "app /my-game/"
  assert storage.database_name("/my-game/index.html") == "app /my-game/"
  assert storage.database_name("/my-game") == "app /"
  assert storage.database_name("/") == "app /"
  assert storage.database_name("/index.html") == "app /"
  assert storage.database_name("") == "app /"
  assert storage.database_name("/a/b/") == "app /a/b/"
}

pub fn an_app_older_than_the_data_is_its_own_error_test() {
  let words =
    "VersionError: The requested version (1) is less than the existing version (2)."
  assert storage.open_error(#("VersionError", words))
    == storage.AppOlderThanData
  assert storage.open_error(#("UnknownError", "UnknownError: gone"))
    == storage.OpenFailed("UnknownError: gone")
  assert storage.open_error(#("", "TypeError: no indexedDB"))
    == storage.OpenFailed("TypeError: no indexedDB")
}

pub fn a_missing_value_is_none_test() {
  assert storage.decode_value(dynamic.nil(), "first_opened", decode.int)
    == Ok(None)
}

pub fn a_stored_value_round_trips_test() {
  let stored = json.int(1_762_980_067_123) |> json.to_string |> dynamic.string
  assert storage.decode_value(stored, "first_opened", decode.int)
    == Ok(Some(1_762_980_067_123))
}

pub fn an_unreadable_value_names_its_key_test() {
  let not_json = dynamic.string("not json")
  let wrong_shape = dynamic.string("\"a string\"")
  let not_a_string = dynamic.int(5)
  assert storage.decode_value(not_json, "first_opened", decode.int)
    == Error(Undecodable("first_opened"))
  assert storage.decode_value(wrong_shape, "first_opened", decode.int)
    == Error(Undecodable("first_opened"))
  assert storage.decode_value(not_a_string, "first_opened", decode.int)
    == Error(Undecodable("first_opened"))
}
