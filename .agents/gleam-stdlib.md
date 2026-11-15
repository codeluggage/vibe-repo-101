# gleam-stdlib.md - stdlib fn catalogs + the decode engine

> Companion to [AGENTS.md](../AGENTS.md). Read when you need a stdlib fn name/signature or are decoding dynamic/JSON/DB rows. Names only - look up the exact signature with `grep -rn "pub fn <name>" build/packages/gleam_stdlib/src/gleam/<mod>.gleam` when unsure. The traps are called out.

`Result(a,e)`/`Option(a)` built-in (`Ok/Error`, `Some/None`). Use **`result.try`** (not `result.then`), **`dict.upsert`** (no `dict.update`). No `list.head`/`list.tail` - use `[x, ..xs]` or `list.first`. No `string.length == 0` - use `string.is_empty`.

**gleam/result:** `map map_error try try_recover unwrap unwrap_error lazy_unwrap is_ok is_error all partition values replace replace_error or lazy_or flatten`

**gleam/option:** `is_some is_none to_result from_result unwrap lazy_unwrap map then flatten or lazy_or values all`

**gleam/list:** `map index_map filter filter_map fold fold_right reduce try_map try_fold find find_map contains length reverse append flatten flat_map first last is_empty take drop repeat key_find group each try_each sort unique zip all any partition prepend wrap intersperse count max`

**gleam/string:** `length is_empty reverse replace lowercase uppercase capitalise append concat join split split_once trim trim_start trim_end starts_with ends_with contains slice drop_start drop_end pad_start pad_end repeat to_graphemes first last pop_grapheme inspect`

**gleam/int:** `parse base_parse to_string to_base_string to_float absolute_value min max clamp compare random remainder modulo power square_root sum product is_even is_odd`
**gleam/float:** `parse to_string truncate round ceiling floor absolute_value negate min max clamp compare power square_root sum product random`

**gleam/dict** `Dict(k,v)`: `new from_list to_list insert get delete keys values size is_empty has_key merge fold map_values filter each upsert` - all return new dict (no mutation). `upsert(dict, key, fn(Option(v)) -> v)`.
**gleam/set** `Set(member)`: `new from_list to_list insert delete contains size is_empty union intersection difference fold filter each`
**gleam/order:** `pub type Order { Lt Eq Gt }` (returned by `compare`).

Most-used signatures (the ones whose label/arg-order trips people):
```gleam
list.fold(over: List(a), from: acc, with: fn(acc, a) -> acc) -> acc
list.filter_map(List(a), fn(a) -> Result(b, e)) -> List(b)     // keeps Ok values
list.try_map(List(a), fn(a) -> Result(b, e)) -> Result(List(b), e)
list.key_find(List(#(k, v)), k) -> Result(v, Nil)
dict.upsert(dict, key, with: fn(Option(v)) -> v) -> Dict(k, v)
result.try(Result(a, e), fn(a) -> Result(b, e)) -> Result(b, e)
```

## gleam/dynamic + gleam/dynamic/decode (decoding lives HERE - old `dynamic.decode_*`/`dynamic.decode2` API is GONE)

```gleam
// gleam/dynamic constructors: bool string int float list properties nil  + classify(Dynamic)->String
// gleam/dynamic/decode:
pub fn run(Dynamic, Decoder(t)) -> Result(t, List(DecodeError))
pub fn success(t) -> Decoder(t)
pub fn failure(placeholder: a, expected: String) -> Decoder(a)
pub fn field(field_name: name, Decoder(t), next: fn(t) -> Decoder(final)) -> Decoder(final)
pub fn optional_field(key: name, default: t, Decoder(t), next) -> Decoder(final)
pub fn subfield(List(name), Decoder(t), next) -> Decoder(final)
pub fn then map one_of optional list dict at        // + primitives below
pub const string  int  float  bool  dynamic : Decoder(...)
```

`field`'s `field_name: name` is a **type var, not String** - takes a **String key** (JSON field / map key) OR an **Int index** (positional tuple/row - see pog rows in gleam-data.md). Same fn both ways: `decode.field("name", ...)` and `decode.field(0, ...)`. The Int form is NOT a separate function. Build with `use` + `field`, finish `success`:

```gleam
import gleam/dynamic/decode
fn user_decoder() -> decode.Decoder(User) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(User(name:, email:))
}
// decode.run(data, user_decoder()) -> Result(User, List(DecodeError))
```

This decoder type is the shared currency: `gleam/json` parsing (gleam-data.md), `pog` row decoding (gleam-data.md), and `rsvp.expect_json` (gleam-frontend.md) all consume a `decode.Decoder(t)`.
