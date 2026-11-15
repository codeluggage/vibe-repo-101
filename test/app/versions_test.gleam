import app/versions
import gleam/list
import gleam/option.{None, Some}

const made = [
  "2026.11.13.1542", "2026.11.13.0342", "2026.11.13.1342", "2026.11.12.1542",
  "2026.11.13.1242", "2026.11.13.0042",
]

fn matching(said: String) -> List(String) {
  list.filter(made, versions.matches(_, said))
}

pub fn four_digits_after_noon_are_one_time_test() {
  assert matching("1542") == ["2026.11.13.1542", "2026.11.12.1542"]
  assert matching("15:42") == ["2026.11.13.1542", "2026.11.12.1542"]
}

pub fn three_or_four_digits_before_noon_may_be_either_test() {
  assert matching("342")
    == ["2026.11.13.1542", "2026.11.13.0342", "2026.11.12.1542"]
  assert matching("0342") == matching("342")
  assert matching("3 42") == matching("342")
  assert matching("1242") == ["2026.11.13.1242", "2026.11.13.0042"]
}

pub fn other_lengths_match_the_end_of_the_version_test() {
  assert matching("13.1542") == ["2026.11.13.1542"]
  assert matching("2026.11.12.1542") == ["2026.11.12.1542"]
  assert matching("42") == made
}

pub fn no_digits_match_nothing_test() {
  assert matching("") == []
  assert matching("the last one") == []
  assert matching("9999") == []
}

pub fn read_tags_keeps_versions_newest_first_test() {
  let text =
    "2026.11.12.1542\taaa\tthe first change\nv1\tbbb\tnot a version\n2026.11.13.0342\tccc\tthe notes have a title\n\n"
  assert versions.read_tags(text)
    == [
      #("2026.11.13.0342", Some("the notes have a title")),
      #("2026.11.12.1542", Some("the first change")),
    ]
}

pub fn read_tags_leaves_a_merge_to_the_commit_under_it_test() {
  let text =
    "2026.11.13.1542\taaa bbb\tMerge remote-tracking branch 'origin/main'\n2026.11.13.1342\t\tthe first change\n"
  assert versions.read_tags(text)
    == [
      #("2026.11.13.1542", None),
      #("2026.11.13.1342", Some("the first change")),
    ]
}

pub fn read_tags_leaves_a_send_once_more_to_the_commit_under_it_test() {
  let text =
    "2026.11.13.1542\taaa\tpublish again\n2026.11.13.1342\tbbb\tpublish again with a new colour\n"
  assert versions.read_tags(text)
    == [
      #("2026.11.13.1542", None),
      #("2026.11.13.1342", Some("publish again with a new colour")),
    ]
}
