import app/version.{Stamp}

pub fn parse_round_trips_test() {
  let assert Ok(parsed) = version.parse("2026.11.13.1542")
  assert version.to_string(parsed) == "2026.11.13.1542"
}

pub fn parse_takes_only_the_release_format_test() {
  assert version.parse("") == Error(Nil)
  assert version.parse("__VERSION__") == Error(Nil)
  assert version.parse("2026-11-12.204107.abc1234") == Error(Nil)
  assert version.parse("2026.11.13") == Error(Nil)
  assert version.parse("2026.11.13.15.42") == Error(Nil)
  assert version.parse("26.11.13.1542") == Error(Nil)
  assert version.parse("2026.1.13.1542") == Error(Nil)
  assert version.parse("2026.11.3.1542") == Error(Nil)
  assert version.parse("2026.11.13.154") == Error(Nil)
  assert version.parse("2026.11.13.15420") == Error(Nil)
  assert version.parse("2026.11.13.15x2") == Error(Nil)
}

pub fn is_newer_orders_by_minute_test() {
  let assert Ok(first) = version.parse("2026.11.13.1542")
  let assert Ok(a_minute_later) = version.parse("2026.11.13.1543")
  let assert Ok(next_day) = version.parse("2026.11.14.0001")
  let assert Ok(next_year) = version.parse("2027.01.01.0000")
  assert version.is_newer(a_minute_later, than: first)
  assert version.is_newer(next_day, than: a_minute_later)
  assert version.is_newer(next_year, than: next_day)
  assert !version.is_newer(first, than: next_year)
  assert !version.is_newer(first, than: first)
}

pub fn version_json_has_three_keys_test() {
  let assert Ok(release) = version.parse("2026.11.13.1542")
  let stamp = Stamp(release:, commit: "776d09c", schema: 1)
  let json = version.to_json(stamp)
  assert json
    == "{\"release\":\"2026.11.13.1542\",\"commit\":\"776d09c\",\"schema\":1}"
  assert version.from_json(json) == Ok(release)
  assert version.stamp_from_json(json) == Ok(stamp)
}

pub fn from_json_reads_only_the_release_test() {
  assert version.from_json("<!doctype html><title>Not found</title>")
    == Error(Nil)
  assert version.from_json("{\"commit\":\"776d09c\"}") == Error(Nil)
  assert version.from_json("{\"release\":\"soon\"}") == Error(Nil)
}

pub fn stamp_from_json_needs_every_key_test() {
  assert version.stamp_from_json("<!doctype html>") == Error(Nil)
  assert version.stamp_from_json("\"2026.11.13.1542\"") == Error(Nil)
  assert version.stamp_from_json("{\"release\":\"2026.11.13.1542\"}")
    == Error(Nil)
  assert version.stamp_from_json(
      "{\"release\":\"soon\",\"commit\":\"776d09c\",\"schema\":1}",
    )
    == Error(Nil)
}
