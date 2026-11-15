# gleam-data.md - JSON + Postgres (json, Squirrel, pog)

> Companion to [AGENTS.md](../AGENTS.md). Read when encoding/parsing JSON or touching Postgres. Decoding reuses `gleam/dynamic/decode` - see [gleam-stdlib.md](gleam-stdlib.md).

## gleam/json - encode + parse (decode reuses dynamic/decode)

```gleam
// encoders: object string int float bool null array(from, of:) preprocessed_array
//           to_string  to_string_tree
json.object([
  #("name", json.string(u.name)),
  #("age", json.int(u.age)),
  #("tags", json.array(u.tags, of: json.string)),
]) |> json.to_string

// parse: feed a decode.Decoder ->
pub fn parse(from: String, using: decode.Decoder(t)) -> Result(t, DecodeError)
pub fn parse_bits(from: BitArray, using) -> Result(t, DecodeError)
// DecodeError: UnexpectedEndOfInput | UnexpectedByte(String) | UnexpectedSequence(String)
//            | UnableToDecode(List(decode.DecodeError))
```

## Squirrel - type-safe SQL -> generated Gleam (v4.x, Postgres >= 16)

Raw SQL in `src/**/sql/*.sql` (one query/file). `gleam run -m squirrel` connects to Postgres, reads each query's column/param types, generates `sql.gleam` (typed fn per file, params + `pog`-ready positional decoder). CI: `gleam run -m squirrel check` (fails if stale). Needs **`pog`** + a **LIVE Postgres at codegen time**. Conn from env: `DATABASE_URL` (`postgres://user:pass@host:port/db`) else `PGHOST PGPORT PGUSER PGDATABASE PGPASSWORD PGCONNECT_TIMEOUT`. Codegen-time only - runtime uses pog.

Type map: `bool`->Bool, `text/varchar/char/citext/name`->String, `float4/8`,`numeric`->Float, `int2/4/8`->Int, `json/jsonb`->encode `json.Json`/decode String, `uuid`->`uuid.Uuid` (youid), `bytea`->BitArray, `date`->`calendar.Date`, `time`->`calendar.TimeOfDay`, `timestamp`->`timestamp.Timestamp`, `T[]`->`List(T)`, enum->generated Gleam type.

## pog - Postgres client (runtime, BEAM-only)

`Config` built with builder fns piped onto `default_config` - NOT a record literal. Pool name is a `process.Name`, created ONCE at startup (`process.new_name`), never in a loop.

```gleam
import gleam/erlang/process
import gleam/option.{Some}
import pog
pub fn start_pool() {
  let name = process.new_name(prefix: "myapp_db")
  let assert Ok(_) =
    pog.default_config(pool_name: name)
    |> pog.host("localhost") |> pog.database("myapp") |> pog.user("postgres")
    |> pog.password(Some("secret"))      // password: Option(String)
    |> pog.pool_size(15)
    |> pog.start
  pog.named_connection(name)             // -> Connection; thread into Wisp Context
}
// builders: host port database user password pool_size rows_as_map
// lifecycle: start(Config)->Result(actor.Started(Connection), _)  |  supervised(Config)->ChildSpecification (prefer in a supervision tree)  |  named_connection(Name)->Connection
// query: query(sql)->Query(Nil) · parameter · returning(decoder) · timeout · execute(query, on: Connection)->Result(Returned(t), QueryError)
// Value constructors for pog.parameter: text int float bool null nullable(fn, Option) array(fn, List) bytea timestamp
```

Hand-rolled parameterized query:

```gleam
pog.query("INSERT INTO uploads (name, body) VALUES ($1, $2) RETURNING id")
|> pog.parameter(pog.text(name))
|> pog.parameter(pog.text(body))
|> pog.returning({ use id <- decode.field(0, decode.int)  decode.success(id) })
|> pog.execute(ctx.db)                   // -> Result(Returned(Int), QueryError)
```

Row decoding is POSITIONAL by default (`rows_as_map` defaults `False` -> each row is an n-tuple in SELECT order). Decode by integer index, not column name:

```gleam
// SELECT id, name, email FROM users
fn user_row(){ use id <- decode.field(0, decode.int)        // index NOT "id"
               use name <- decode.field(1, decode.string)
               use email <- decode.field(2, decode.string)
               decode.success(User(id:, name:, email:)) }
```

String-key decoding works ONLY with `pog.rows_as_map(config, True)`. Mismatch compiles fine, fails/decodes wrong at runtime - silent bug. Squirrel-generated fns build the correct positional decoder for you - prefer them over hand-written `pog.query`+`returning`. No `pog.query_error_to_string` - render a `QueryError` with `string.inspect`. Don't pattern-match its variants from memory (they're easy to mis-name) - handle with `_ ->` + inspect, or compile to let the warning list the real ones. `pog.start` for demo/entry-point; `pog.supervised` for production (pool restarts on crash). Hand-roll `pog.query` to bootstrap before the schema/DB exists, switch to Squirrel once it's up. Pass the `Connection` into your Wisp `Context` (see [gleam-backend.md](gleam-backend.md)).
