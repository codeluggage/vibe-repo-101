import app/live_check.{CannotTell, MayGoLive, NotLater, OlderLayout}
import app/version.{type Stamp, Stamp}

fn stamp(release: String, schema: Int) -> Stamp {
  let assert Ok(release) = version.parse(release)
  Stamp(release:, commit: "aaaaaaa", schema:)
}

fn live(release: String, schema: Int) -> Result(#(Int, String), String) {
  Ok(#(200, version.to_json(stamp(release, schema))))
}

const new = "2026.11.13.1542"

pub fn a_later_version_may_go_live_test() {
  let assert MayGoLive(_) =
    live_check.decide(stamp(new, 1), live("2026.11.13.1541", 1))
  let assert MayGoLive(_) =
    live_check.decide(stamp(new, 2), live("2026.11.12.2359", 1))
}

pub fn the_same_or_an_older_version_may_not_test() {
  let assert NotLater(_) = live_check.decide(stamp(new, 1), live(new, 1))
  let assert NotLater(_) =
    live_check.decide(stamp(new, 1), live("2026.11.13.1543", 1))
}

pub fn an_older_saved_data_layout_may_not_test() {
  let assert OlderLayout(_) =
    live_check.decide(stamp(new, 1), live("2026.11.13.1541", 2))
  // Whatever the clocks say, so publish can ask this alone.
  let assert OlderLayout(_) = live_check.decide(stamp(new, 1), live(new, 2))
  let assert OlderLayout(_) =
    live_check.decide(stamp(new, 1), live("2026.11.13.1543", 2))
}

pub fn a_new_site_may_go_live_test() {
  let assert MayGoLive(_) =
    live_check.decide(stamp(new, 1), Ok(#(404, "Not found")))
}

pub fn any_other_answer_may_not_test() {
  let assert CannotTell(_) = live_check.decide(stamp(new, 1), Error("offline"))
  let assert CannotTell(_) = live_check.decide(stamp(new, 1), Ok(#(500, "")))
  let assert CannotTell(_) =
    live_check.decide(stamp(new, 1), Ok(#(200, "<!doctype html>")))
  let assert CannotTell(_) =
    live_check.decide(stamp(new, 1), Ok(#(200, "{\"release\":\"soon\"}")))
}
