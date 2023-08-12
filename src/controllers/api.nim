import std/prelude
import std/strutils
import std/strformat
import std/base64
import std/uri
import std/json

import prologue
import easy_sqlite3

import ../emaildb/migration
import ../db/users
import ../context

proc get*(ctx: Context) {.async, gcsafe.} =
  let db = AppContext(ctx).db
  let current_user = db[].get_user(ctx.session.getOrDefault("email", ""))

  resp json_response(%*{
    "ok": %true,
    "user": %current_user
  })

proc post*(ctx: Context) {.async, gcsafe.} =
  let req = parse_json(ctx.request.body())
  let users_db = AppContext(ctx).db
  let current_user = users_db[].get_user(ctx.session.getOrDefault("email", ""))

  let sql = req["sql"].to(string)
  if sql == "":
    resp json_response(%*{ "ok": %true })
    return

  var db: Database
  if current_user.is_none:
    db = initDatabase(":memory:")
  else:
    db = open_user_database(AppContext(ctx).dbdir, AppContext(ctx).dbprefix, current_user.get.local_part)

  db.setAuthorizer do (req: AuthorizerRequest) -> AuthorizerResult:
    result = deny
    case req.action_code
    of select, recursive:
      result = ok
    of read:
      case req.target_table_name
      of "email", "raw_email", "part", "header_name", "header_data", "header":
        result = ok
      else:
        discard
    of function:
      case req.function_name
      of "count", "printf", "group_concat":
        result = ok
      else:
        discard
    else:
      discard
    echo &"authorize {req.repr} = {result}"

  let st = db.newStatement(sql)
  var res_rows: seq[JsonNode]
  for line in st.rows():
    var res_line: seq[JsonNode]
    for col in line:
      case col.data_type
      of dt_integer:
        res_line.add(%col[int])
      of dt_float:
        res_line.add(%col[float64])
      of dt_text:
        res_line.add(%col[string])
      of dt_blob:
        res_line.add(%col[string])
      of dt_null:
        res_line.add(newJNull())
    res_rows.add(%res_line)

  resp json_response(%*{ "rows": %res_rows })
