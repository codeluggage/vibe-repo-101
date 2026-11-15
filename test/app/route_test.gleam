import app/route.{Home, NotePage}

pub fn parse_reads_each_screen_test() {
  assert route.parse("") == Home
  assert route.parse("#") == Home
  assert route.parse("#/") == Home
  assert route.parse("#/note/abc-1") == NotePage("abc-1")
}

pub fn to_hash_writes_each_screen_test() {
  assert route.to_hash(Home) == "#/"
  assert route.to_hash(NotePage("abc-1")) == "#/note/abc-1"
}

pub fn an_id_that_needs_encoding_round_trips_test() {
  let note = NotePage("a b/c#d?")
  let hash = route.to_hash(note)
  assert hash == "#/note/a%20b%2Fc%23d%3F"
  assert route.parse(hash) == note
}

pub fn unknown_hashes_are_home_test() {
  assert route.parse("#/nowhere") == Home
  assert route.parse("#/note") == Home
  assert route.parse("#/note/") == Home
  assert route.parse("#/note/a/b") == Home
  assert route.parse("#/note/%E0%A4%A") == Home
}
